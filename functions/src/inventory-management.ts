import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Cloud Function to handle inventory reservation during order processing
 * Called when an order is created to ensure atomic inventory updates
 */
export const reserveInventoryForOrder = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { items } = data;
  
  if (!items || !Array.isArray(items)) {
    throw new functions.https.HttpsError('invalid-argument', 'Items array is required');
  }

  try {
    // Use a transaction to ensure atomicity across all products
    const result = await db.runTransaction(async (transaction) => {
      const reservations: any[] = [];
      
      // First pass: read all products and validate stock
      for (const item of items) {
        const { productId, quantity, selectedVariants } = item;
        
        if (!productId || !quantity) {
          throw new Error(`Invalid item: missing productId or quantity`);
        }

        const productRef = db.collection('products').doc(productId);
        const productSnap = await transaction.get(productRef);
        
        if (!productSnap.exists) {
          throw new Error(`Product ${productId} not found`);
        }

        const product = productSnap.data()!;
        
        if (!product.isActive) {
          throw new Error(`Product ${product.name} is not active`);
        }

        // Check stock availability
        if (selectedVariants && Object.keys(selectedVariants).length > 0) {
          // Variant-based product
          const variants = product.variants || [];
          const updatedVariants = [...variants];

          for (const variant of updatedVariants) {
            const selectedOption = selectedVariants[variant.name];
            
            if (selectedOption && variant.trackInventory) {
              const currentStock = variant.stockByOption?.[selectedOption] || 0;
              
              if (currentStock < quantity) {
                throw new Error(`Insufficient stock for ${product.name} - ${variant.name}: ${selectedOption}`);
              }
              
              // Update stock in memory for this transaction
              if (!variant.stockByOption) variant.stockByOption = {};
              variant.stockByOption[selectedOption] = currentStock - quantity;
            }
          }

          reservations.push({
            productRef,
            isVariant: true,
            updatedVariants,
            originalProduct: product,
          });
        } else {
          // Simple product
          if (product.stock < quantity) {
            throw new Error(`Insufficient stock for ${product.name}`);
          }

          reservations.push({
            productRef,
            isVariant: false,
            newStock: product.stock - quantity,
            originalProduct: product,
          });
        }
      }

      // Second pass: apply all updates atomically
      for (const reservation of reservations) {
        if (reservation.isVariant) {
          transaction.update(reservation.productRef, {
            variants: reservation.updatedVariants,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(reservation.productRef, {
            stock: reservation.newStock,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      return { success: true, reservedItems: items.length };
    });

    return result;
  } catch (error) {
    console.error('Error reserving inventory:', error);
    throw new functions.https.HttpsError('internal', `Failed to reserve inventory: ${error instanceof Error ? error.message : String(error)}`);
  }
});

/**
 * Cloud Function to release inventory when an order is cancelled
 */
export const releaseInventoryForOrder = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { items } = data;
  
  if (!items || !Array.isArray(items)) {
    throw new functions.https.HttpsError('invalid-argument', 'Items array is required');
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      // First pass: read all products
      for (const item of items) {
        const { productId, quantity, selectedVariants } = item;
        
        const productRef = db.collection('products').doc(productId);
        const productSnap = await transaction.get(productRef);
        
        if (!productSnap.exists) {
          console.warn(`Product ${productId} not found during inventory release`);
          continue;
        }

        const product = productSnap.data()!;

        if (selectedVariants && Object.keys(selectedVariants).length > 0) {
          // Variant-based product - restore stock
          const variants = product.variants || [];
          const updatedVariants = [...variants];

          for (const variant of updatedVariants) {
            const selectedOption = selectedVariants[variant.name];
            
            if (selectedOption && variant.trackInventory) {
              const currentStock = variant.stockByOption?.[selectedOption] || 0;
              
              if (!variant.stockByOption) variant.stockByOption = {};
              variant.stockByOption[selectedOption] = currentStock + quantity;
            }
          }

          transaction.update(productRef, {
            variants: updatedVariants,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          // Simple product - restore stock
          transaction.update(productRef, {
            stock: product.stock + quantity,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      return { success: true, releasedItems: items.length };
    });

    return result;
  } catch (error) {
    console.error('Error releasing inventory:', error);
    throw new functions.https.HttpsError('internal', `Failed to release inventory: ${error instanceof Error ? error.message : String(error)}`);
  }
});

/**
 * Automatically release inventory when order status changes to cancelled/failed
 */
export const handleOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // Check if status changed to cancelled or failed
    const shouldReleaseInventory = 
      (afterData.status === 'cancelled' || afterData.status === 'failed') &&
      beforeData.status !== afterData.status &&
      (beforeData.status === 'pending' || beforeData.status === 'paid');

    if (!shouldReleaseInventory) {
      return;
    }

    try {
      const items = afterData.items || [];
      
      await db.runTransaction(async (transaction) => {
        for (const item of items) {
          const productRef = db.collection('products').doc(item.productId);
          const productSnap = await transaction.get(productRef);
          
          if (!productSnap.exists) continue;
          
          const product = productSnap.data()!;
          const quantity = item.quantity || 1;
          const selectedVariants = item.selectedVariants;

          if (selectedVariants && Object.keys(selectedVariants).length > 0) {
            // Restore variant stock
            const variants = product.variants || [];
            const updatedVariants = [...variants];

            for (const variant of updatedVariants) {
              const selectedOption = selectedVariants[variant.name];
              
              if (selectedOption && variant.trackInventory) {
                const currentStock = variant.stockByOption?.[selectedOption] || 0;
                
                if (!variant.stockByOption) variant.stockByOption = {};
                variant.stockByOption[selectedOption] = currentStock + quantity;
              }
            }

            transaction.update(productRef, {
              variants: updatedVariants,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            // Restore simple product stock
            transaction.update(productRef, {
              stock: product.stock + quantity,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      });

      console.log(`Released inventory for cancelled order: ${context.params.orderId}`);
    } catch (error) {
      console.error(`Error releasing inventory for order ${context.params.orderId}:`, error);
    }
  }); 