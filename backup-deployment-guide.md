# 🔄 **Shoppy Backup System Deployment Guide**

## **Overview**

This guide will help you deploy the **critical automated backup system** for your Shoppy application. This system provides:

- ✅ **Automated daily backups** at 2 AM UTC
- ✅ **Manual backup triggers** for super admins
- ✅ **Point-in-time restore** capabilities
- ✅ **GDPR-compliant data export**
- ✅ **Backup monitoring & alerts**
- ✅ **30-day retention policy**

---

## **🚀 Quick Deployment (5 minutes)**

### **Step 1: Create Cloud Storage Bucket**
```bash
# Create backup storage bucket
gsutil mb gs://shoppy-firestore-backups

# Set bucket permissions (admin access only)
gsutil iam ch serviceAccount:shoppy-6d81f@appspot.gserviceaccount.com:admin gs://shoppy-firestore-backups
```

### **Step 2: Deploy Cloud Functions**
```bash
cd functions

# Install dependencies
npm install

# Build functions
npm run build

# Deploy backup functions
firebase deploy --only functions:scheduledFirestoreBackup,functions:triggerManualBackup,functions:restoreFromBackup,functions:getBackupHistory,functions:exportUserData
```

### **Step 3: Verify Deployment**
```bash
# Check if functions deployed successfully
firebase functions:list

# Test backup function (optional)
firebase functions:shell
> scheduledFirestoreBackup()
```

---

## **🔧 Manual Setup (if quick deployment fails)**

### **Prerequisites**
- Firebase CLI installed and authenticated
- Google Cloud SDK (for gsutil)
- Project admin permissions

### **1. Create Storage Bucket**
```bash
# Alternative method using Firebase CLI
firebase functions:config:set backup.bucket="shoppy-firestore-backups"

# Or create via Google Cloud Console:
# 1. Go to Google Cloud Console > Storage
# 2. Create bucket: shoppy-firestore-backups
# 3. Set location: us-central1 (same as Firebase)
# 4. Set access control: Uniform
```

### **2. Set Function Configuration**
```bash
# Set backup configuration
firebase functions:config:set \
  backup.schedule="0 2 * * *" \
  backup.retention_days="30" \
  backup.bucket="shoppy-firestore-backups"

# View current config
firebase functions:config:get
```

### **3. Deploy Individual Functions**
```bash
# Deploy scheduled backup
firebase deploy --only functions:scheduledFirestoreBackup

# Deploy manual backup trigger
firebase deploy --only functions:triggerManualBackup

# Deploy restore function
firebase deploy --only functions:restoreFromBackup

# Deploy backup history
firebase deploy --only functions:getBackupHistory

# Deploy GDPR export
firebase deploy --only functions:exportUserData
```

---

## **🔍 Testing & Verification**

### **Test Manual Backup**
1. Open Super Admin panel
2. Navigate to "Backup Management"
3. Select collections to backup
4. Click "Create Backup"
5. Monitor progress and verify success

### **Test Backup History**
```bash
# Check backup logs in Firestore
firebase firestore:get backup_logs

# Or check in Firebase Console:
# Firestore Database > backup_logs collection
```

### **Test Scheduled Backup**
```bash
# Trigger scheduled function manually for testing
firebase functions:shell
> scheduledFirestoreBackup()

# Or wait for next 2 AM UTC run
```

---

## **📊 Monitoring & Alerts**

### **Set Up Monitoring**
1. **Firebase Console**: Functions > Usage tab
2. **Cloud Monitoring**: Set up alerts for function failures
3. **Super Admin Notifications**: Automatic backup status alerts

### **Key Metrics to Monitor**
- ✅ **Backup Success Rate**: Should be 100%
- ✅ **Backup Duration**: Typically 2-5 minutes
- ✅ **Storage Usage**: Monitor growth over time
- ✅ **Function Errors**: Alert on any failures

### **Alert Configuration**
```bash
# Create alert policy for backup failures
gcloud alpha monitoring policies create backup-failure-policy.yaml

# Example policy (create backup-failure-policy.yaml):
```

```yaml
displayName: "Backup Function Failures"
conditions:
  - displayName: "Function execution errors"
    conditionThreshold:
      filter: 'resource.type="cloud_function" resource.label.function_name="scheduledFirestoreBackup"'
      comparison: COMPARISON_EQUAL
      thresholdValue: 1
      duration: "60s"
notificationChannels:
  - "projects/shoppy-6d81f/notificationChannels/YOUR_CHANNEL_ID"
```

---

## **🔐 Security Configuration**

### **IAM Permissions**
```bash
# Backup service needs these permissions:
# - Firestore Admin
# - Storage Admin  
# - Cloud Functions Invoker

# Verify current permissions
gcloud projects get-iam-policy shoppy-6d81f
```

### **Access Control**
- ✅ **Backup triggers**: Super admins only
- ✅ **Restore operations**: Super admins only
- ✅ **Backup history**: Super admins only
- ✅ **Storage bucket**: Service account only

---

## **📋 Post-Deployment Checklist**

### **Immediate Tasks** (within 24 hours)
- [ ] Verify first automated backup runs successfully
- [ ] Test manual backup via Super Admin panel
- [ ] Confirm backup notifications are working
- [ ] Document backup/restore procedures for team

### **Weekly Tasks**
- [ ] Review backup success rates
- [ ] Monitor storage usage growth
- [ ] Test restore procedure (on staging environment)
- [ ] Update disaster recovery documentation

### **Monthly Tasks**  
- [ ] Verify old backups are being cleaned up (30-day retention)
- [ ] Review and optimize backup size
- [ ] Test full disaster recovery scenario
- [ ] Update backup procedures if needed

---

## **🚨 Disaster Recovery**

### **Emergency Restore Procedure**
1. **Access Super Admin Panel** → Backup Management
2. **Select Latest Successful Backup**
3. **Choose Collections to Restore**
4. **Enter Confirmation Code**: `RESTORE_CONFIRMED`
5. **Monitor Restore Progress** (can take 10-30 minutes)
6. **Verify Data Integrity** after restore

### **Alternative Command-Line Restore**
```bash
# If admin panel is unavailable
firebase functions:shell
> restoreFromBackup({
    backupPath: "gs://shoppy-firestore-backups/backup_TIMESTAMP",
    collections: ["users", "stores", "orders"],
    confirmationCode: "RESTORE_CONFIRMED"
  })
```

---

## **🔧 Troubleshooting**

### **Common Issues**

**Issue**: Backup function timeout
```bash
# Solution: Increase function timeout
firebase functions:config:set backup.timeout="540"
firebase deploy --only functions:scheduledFirestoreBackup
```

**Issue**: Storage permission denied
```bash
# Solution: Check bucket permissions
gsutil iam get gs://shoppy-firestore-backups
gsutil iam ch serviceAccount:shoppy-6d81f@appspot.gserviceaccount.com:admin gs://shoppy-firestore-backups
```

**Issue**: Function memory issues
```bash
# Solution: Increase memory allocation in functions/src/firestore-backup.ts
// Add before export:
// const runtimeOpts = {
//   timeoutSeconds: 540,
//   memory: '2GB' as const
// }
```

### **Debug Commands**
```bash
# View function logs
firebase functions:log --only scheduledFirestoreBackup

# Check function configuration  
firebase functions:config:get

# Test bucket access
gsutil ls gs://shoppy-firestore-backups

# Verify Firestore rules
firebase firestore:rules:validate
```

---

## **💰 Cost Optimization**

### **Expected Costs** (per month)
- **Cloud Functions**: ~$2-5 (scheduled + manual backups)
- **Cloud Storage**: ~$1-3 (depending on data size)
- **Network Egress**: ~$0.50 (backup uploads)
- **Total Monthly**: ~$3-8

### **Cost Monitoring**
```bash
# Set up billing alerts
gcloud billing budgets create \
  --billing-account=YOUR_BILLING_ACCOUNT \
  --display-name="Backup System Budget" \
  --budget-amount=10USD
```

---

## **✅ Success Confirmation**

Your backup system is successfully deployed when:

1. ✅ Daily backups run automatically at 2 AM UTC
2. ✅ Manual backups work from Super Admin panel  
3. ✅ Backup history shows successful entries
4. ✅ Super admins receive backup notifications
5. ✅ Storage bucket contains backup files
6. ✅ Restore functionality tested (on staging)

---

## **📞 Support & Maintenance**

### **Emergency Contacts**
- **Firebase Support**: [firebase.google.com/support](https://firebase.google.com/support)
- **Google Cloud Support**: Available 24/7 with paid plans

### **Documentation Links**
- **Firestore Backup**: [Firebase Docs](https://firebase.google.com/docs/firestore/manage-data/export-import)
- **Cloud Functions**: [Functions Docs](https://firebase.google.com/docs/functions)
- **Cloud Storage**: [Storage Docs](https://cloud.google.com/storage/docs)

**Your data is now protected! 🛡️** 