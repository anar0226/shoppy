// Simple script to create the featured stores configuration
// Run this in your browser console when logged into your Firebase project

const featuredStoresData = {
  storeIds: [
    'TLLb3tqzvU2TZSsNPol9',
    'store_rbA5yLk0vadvSWarOpzYW1bRRUz1'
  ],
  createdAt: new Date(),
  updatedAt: new Date(),
  description: 'Stores featured on the home screen seller cards'
};

console.log('Featured stores configuration to set:', featuredStoresData);
console.log('');
console.log('To set up featured stores, run this in your Super Admin panel or use Firebase Console:');
console.log('1. Go to Firebase Console > Firestore Database');
console.log('2. Create collection: platform_settings');
console.log('3. Create document: featured_stores');
console.log('4. Add the following data:');
console.log(JSON.stringify(featuredStoresData, null, 2));
console.log('');
console.log('Or use the Featured Stores page in Super Admin panel to set these stores:');
console.log('- TLLb3tqzvU2TZSsNPol9');
console.log('- store_rbA5yLk0vadvSWarOpzYW1bRRUz1'); 