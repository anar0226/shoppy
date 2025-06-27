// Simple Node.js script to create super admin account
// Run with: node create_super_admin.js

const admin = require('firebase-admin');

// Initialize Firebase Admin with your service account
// You can download the service account key from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./path/to/serviceAccountKey.json'); // Update this path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'shoppy-6d81f'
});

const firestore = admin.firestore();

async function createSuperAdmin() {
  try {
    // User details - CHANGE THESE TO YOUR DETAILS
    const adminData = {
      name: 'Your Name',              // Change this
      email: 'admin@yourshoppy.com',  // Change this
      password: 'your_secure_password' // Change this
    };

    console.log('🚀 Creating Super Admin account...');
    console.log('📧 Email:', adminData.email);
    console.log('👤 Name:', adminData.name);

    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: adminData.email,
      password: adminData.password,
      displayName: adminData.name,
    });

    console.log('✅ Firebase Auth user created:', userRecord.uid);

    // Add super admin document to Firestore
    await firestore.collection('super_admins').doc(userRecord.uid).set({
      name: adminData.name,
      email: adminData.email,
      role: 'super_administrator',
      permissions: ['all'], // Full access
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'setup_script',
    });

    console.log('✅ Super admin document created in Firestore');

    // Log the admin creation
    await firestore.collection('admin_activity_logs').add({
      adminId: userRecord.uid,
      action: 'super_admin_created',
      data: {
        email: adminData.email,
        name: adminData.name,
        method: 'setup_script'
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Activity logged');

    console.log('\n🎉 SUCCESS!');
    console.log('📋 Super Admin Details:');
    console.log('   ID:', userRecord.uid);
    console.log('   Email:', adminData.email);
    console.log('   Name:', adminData.name);
    console.log('\n🚀 You can now run the Super Admin panel with:');
    console.log('   flutter run -t lib/super_admin/super_admin_main.dart');

    process.exit(0);

  } catch (error) {
    console.error('❌ Error creating super admin:', error);
    
    if (error.code === 'auth/email-already-exists') {
      console.log('\n💡 The email already exists. If this is your account, you can:');
      console.log('   1. Use a different email');
      console.log('   2. Or manually add the existing user to super_admins collection');
    }
    
    process.exit(1);
  }
}

// Instructions for setup
console.log('🏢 Shoppy Super Admin Setup Script');
console.log('===================================');
console.log('');
console.log('📋 Before running this script:');
console.log('1. Download your Firebase service account key:');
console.log('   → Go to Firebase Console > Project Settings > Service Accounts');
console.log('   → Click "Generate new private key"');
console.log('   → Save as serviceAccountKey.json in this folder');
console.log('');
console.log('2. Install firebase-admin:');
console.log('   → npm install firebase-admin');
console.log('');
console.log('3. Update the admin details in this script (lines 10-14)');
console.log('');
console.log('4. Update the service account path (line 7)');
console.log('');
console.log('5. Run: node create_super_admin.js');
console.log('');

// Uncomment the line below after setup
// createSuperAdmin();

console.log('⚠️  Script is in setup mode. Please follow the instructions above.');
console.log('   Then uncomment line 82 and run again.'); 