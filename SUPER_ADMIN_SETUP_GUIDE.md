# 🛠️ Super Admin Setup Guide - Firebase Console Method

## 🎯 **Method 1: Create User in Firebase Auth (Recommended)**

### **Step 1: Create Firebase Auth User**
1. Go to: https://console.firebase.google.com/project/shoppy-6d81f/authentication/users
2. Click **"Add user"**
3. Enter:
   - **Email**: `anar0226@gmail.com`
   - **Password**: `Anaranar12345`
4. Click **"Add user"**
5. **📋 COPY THE USER UID** (something like: `abc123def456ghi789...`)

### **Step 2: Create Super Admin Document**
1. Go to: https://console.firebase.google.com/project/shoppy-6d81f/firestore/data
2. If `super_admins` collection exists:
   - Delete the document: `rbA5yLk0vadvSWarOpzYW1bRRUz1`
3. Create new collection called `super_admins` (if doesn't exist)
4. Click **"Add document"**
5. **Document ID**: Paste the **User UID from Step 1**
6. Add these fields **exactly**:

```
Field: name          Type: string      Value: Anar (or your name)
Field: email         Type: string      Value: anar0226@gmail.com
Field: role          Type: string      Value: super_administrator
Field: permissions   Type: array       Value: all
Field: isActive      Type: boolean     Value: true
Field: createdAt     Type: timestamp   Value: [click "Current timestamp"]
Field: createdBy     Type: string      Value: manual
```

7. Click **"Save"**

---

## 🎯 **Method 2: If User Already Exists**

### **Step 1: Find Existing User UID**
1. Go to: https://console.firebase.google.com/project/shoppy-6d81f/authentication/users
2. Look for user: `anar0226@gmail.com`
3. **Copy the UID** (long string like: `rbA5yLk0vadvSWarOpzYW1bRRUz1`)

### **Step 2: Update Firestore Document**
1. Go to: https://console.firebase.google.com/project/shoppy-6d81f/firestore/data
2. Navigate to `super_admins` collection
3. Find document with ID: `rbA5yLk0vadvSWarOpzYW1bRRUz1`
4. **Edit the document** and ensure it has ALL these fields:

```
✅ name: "Anar" (string)
✅ email: "anar0226@gmail.com" (string)  
✅ role: "super_administrator" (string)
✅ permissions: ["all"] (array - important: square brackets!)
✅ isActive: true (boolean - important: not string "true")
✅ createdAt: [timestamp]
✅ createdBy: "manual" (string)
```

---

## 🎯 **Method 3: Quick Fix for Current Setup**

If your Firebase Auth user already exists with UID `rbA5yLk0vadvSWarOpzYW1bRRUz1`:

1. Go to: https://console.firebase.google.com/project/shoppy-6d81f/firestore/data/~2Fsuper_admins~2FrbA5yLk0vadvSWarOpzYW1bRRUz1
2. Check each field type carefully:
   - `permissions` must be **array**: `["all"]` (NOT string)
   - `isActive` must be **boolean**: `true` (NOT string)
   - `role` must be exactly: `"super_administrator"`

---

## 🧪 **Test Your Setup**

After completing any method above:

1. **Run Super Admin App**:
   ```bash
   flutter run -t lib/super_admin/super_admin_main.dart -d chrome
   ```

2. **Login with**:
   - Email: `anar0226@gmail.com`
   - Password: `Anaranar12345`

3. **You should see**: Platform dashboard with real-time analytics

---

## 🚨 **Common Issues & Fixes**

### **"Invalid credentials or insufficient permissions"**
- ✅ **Check**: Firebase Auth user exists with correct email/password
- ✅ **Check**: Firestore document ID matches Firebase Auth UID exactly
- ✅ **Check**: All required fields exist in Firestore document
- ✅ **Check**: `isActive` is boolean `true`, not string `"true"`
- ✅ **Check**: `permissions` is array `["all"]`, not string `"all"`

### **"User not found"**
- ✅ Create Firebase Auth user first
- ✅ Use exact email: `anar0226@gmail.com`

### **"Document not found"**  
- ✅ Firestore document ID must match Firebase Auth UID exactly
- ✅ Document must be in `super_admins` collection

---

## 🎉 **Success Checklist**

✅ Firebase Auth user exists: `anar0226@gmail.com`  
✅ Firestore document ID = Firebase Auth UID  
✅ All 7 required fields in document  
✅ Field types are correct (boolean, array, string)  
✅ `isActive` = `true` (boolean)  
✅ `permissions` = `["all"]` (array)  

**Once all ✅ are complete, login should work perfectly!** 