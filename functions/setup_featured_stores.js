const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function setupFeaturedStores() {
  try {
    console.log('Setting up featured stores configuration...');
    
    // Set the featured stores with the specific IDs
    await db.collection('platform_settings').doc('featured_stores').set({
      storeIds: [
        'TLLb3tqzvU2TZSsNPol9',
        'store_rbA5yLk0vadvSWarOpzYW1bRRUz1'
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Stores featured on the home screen seller cards'
    });

    console.log('✅ Featured stores configuration created successfully!');
    console.log('Featured stores:');
    console.log('- TLLb3tqzvU2TZSsNPol9');
    console.log('- store_rbA5yLk0vadvSWarOpzYW1bRRUz1');
    
    // Verify the stores exist
    console.log('\nVerifying stores exist...');
    
    const store1 = await db.collection('stores').doc('TLLb3tqzvU2TZSsNPol9').get();
    const store2 = await db.collection('stores').doc('store_rbA5yLk0vadvSWarOpzYW1bRRUz1').get();
    
    if (store1.exists) {
      console.log(`✅ Store 1 found: ${store1.data().name}`);
    } else {
      console.log('❌ Store 1 (TLLb3tqzvU2TZSsNPol9) not found');
    }
    
    if (store2.exists) {
      console.log(`✅ Store 2 found: ${store2.data().name}`);
    } else {
      console.log('❌ Store 2 (store_rbA5yLk0vadvSWarOpzYW1bRRUz1) not found');
    }

  } catch (error) {
    console.error('Error setting up featured stores:', error);
  } finally {
    process.exit();
  }
}

setupFeaturedStores(); 