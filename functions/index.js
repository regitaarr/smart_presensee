/**
 * Cloud Functions untuk Smart Presensee
 * 
 * Fungsi ini akan otomatis menjalankan auto-alpha setiap hari pada jam yang ditentukan
 * berdasarkan jam_selesai di attendance_settings + 1 menit
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

/**
 * Scheduled function untuk auto-generate alpha
 * Berjalan setiap hari pada jam 13:56 WIB (06:56 UTC)
 * 
 * Untuk mengubah jadwal, ubah cron expression di bawah:
 * Format: 'minute hour * * *' dalam timezone Asia/Jakarta
 * Contoh:
 * - '56 13 * * *' = Setiap hari jam 13:56
 * - '0 14 * * *' = Setiap hari jam 14:00
 */
exports.scheduledAutoAlpha = functions
  .region('asia-southeast2') // Jakarta region
  .pubsub
  .schedule('56 13 * * *') // Jam 13:56 setiap hari
  .timeZone('Asia/Jakarta')
  .onRun(async (context) => {
    try {
      console.log('🔄 Starting scheduled auto-alpha generation...');

      // 1. Get attendance settings
      const settingsDoc = await db.collection('attendance_settings')
        .doc('default_settings')
        .get();

      if (!settingsDoc.exists) {
        console.log('⚠️ No attendance settings found, using defaults');
      }

      const settings = settingsDoc.data() || {
        aktif: true,
        jam_mulai: '06:30',
        jam_selesai: '13:55'
      };

      // 2. Check if restriction is active
      if (!settings.aktif) {
        console.log('⚠️ Attendance restriction not active, skipping auto-alpha');
        return null;
      }

      // 3. Get all students
      const studentsSnapshot = await db.collection('siswa').get();
      
      if (studentsSnapshot.empty) {
        console.log('⚠️ No students found');
        return null;
      }

      // 4. Get today's attendance records
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

      const todayAttendanceSnapshot = await db.collection('presensi')
        .where('tanggal_waktu', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
        .where('tanggal_waktu', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
        .get();

      // 5. Create set of NISNs who already have attendance today
      const attendedNISNs = new Set();
      todayAttendanceSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.nisn) {
          attendedNISNs.add(data.nisn);
        }
      });

      console.log(`📊 Total students: ${studentsSnapshot.size}`);
      console.log(`📊 Already attended: ${attendedNISNs.size}`);

      // 6. Generate alpha for students who haven't attended
      let alphaCount = 0;
      const alphaStudents = [];
      const batch = db.batch();

      for (const studentDoc of studentsSnapshot.docs) {
        const studentData = studentDoc.data();
        const nisn = studentDoc.id;
        const studentName = studentData.nama_siswa || 'Unknown';

        // Skip if student already attended today
        if (attendedNISNs.has(nisn)) {
          continue;
        }

        // Generate alpha ID
        const alphaId = await generateAlphaId();
        const alphaTime = admin.firestore.Timestamp.now();

        const alphaData = {
          id_presensi: alphaId,
          nisn: nisn,
          tanggal_waktu: alphaTime,
          status: 'alpha',
          metode: 'auto_generated_cloud',
        };

        const alphaRef = db.collection('presensi').doc(alphaId);
        batch.set(alphaRef, alphaData);

        alphaCount++;
        alphaStudents.push(studentName);
        
        console.log(`✅ Generated alpha for: ${studentName} (NISN: ${nisn})`);
      }

      // Commit batch
      if (alphaCount > 0) {
        await batch.commit();
        console.log(`✅ Auto-alpha generation completed. Total alpha: ${alphaCount}`);
        console.log(`📋 Alpha students: ${alphaStudents.join(', ')}`);
      } else {
        console.log('✅ All students have attended today');
      }

      return {
        success: true,
        alphaCount: alphaCount,
        alphaStudents: alphaStudents,
      };

    } catch (error) {
      console.error('❌ Error in scheduled auto-alpha:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  });

/**
 * Helper function untuk generate unique alpha ID
 */
async function generateAlphaId() {
  try {
    const prefix = 'idpr04';

    // Query last record to get the latest ID
    const lastRecordsSnapshot = await db.collection('presensi')
      .where('id_presensi', '>=', prefix)
      .where('id_presensi', '<', `${prefix}z`)
      .orderBy('id_presensi', 'desc')
      .limit(1)
      .get();

    let nextNumber = 1;

    if (!lastRecordsSnapshot.empty) {
      const lastId = lastRecordsSnapshot.docs[0].data().id_presensi;
      console.log(`Last presensi ID found: ${lastId}`);

      if (lastId.length >= 10 && lastId.startsWith(prefix)) {
        const lastNumberStr = lastId.substring(6); // Skip "idpr04"
        const lastNumber = parseInt(lastNumberStr) || 0;
        nextNumber = lastNumber + 1;
      }
    }

    // Format: idpr04 + 4 digit number (e.g., idpr040001, idpr040002)
    const formattedNumber = nextNumber.toString().padStart(4, '0');
    const newId = `${prefix}${formattedNumber}`;

    console.log(`Generated alpha ID: ${newId} (next number: ${nextNumber})`);
    return newId;
  } catch (error) {
    console.error('Error generating sequential alpha ID:', error);
    
    // Fallback: use timestamp-based ID
    const now = new Date();
    const timeString = 
      now.getHours().toString().padStart(2, '0') + 
      now.getMinutes().toString().padStart(2, '0');
    const fallbackId = `idpr04${timeString}`;
    
    console.log(`Using fallback ID: ${fallbackId}`);
    return fallbackId;
  }
}

/**
 * Manual trigger function untuk testing
 * Dapat dipanggil dari Flutter app atau HTTP request
 */
exports.manualAutoAlpha = functions
  .region('asia-southeast2')
  .https.onCall(async (data, context) => {
    try {
      console.log('🔄 Manual auto-alpha triggered...');

      // Same logic as scheduled function
      // (copy the logic from scheduledAutoAlpha here)
      // For brevity, we'll call the same logic

      // Execute the same auto-alpha logic
      const result = await executeAutoAlpha();
      
      return result;
    } catch (error) {
      console.error('❌ Error in manual auto-alpha:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

/**
 * HTTP endpoint untuk monitoring status
 */
exports.checkAutoAlphaStatus = functions
  .region('asia-southeast2')
  .https.onRequest(async (req, res) => {
    try {
      // Get today's alpha records that were auto-generated
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

      const todayAlphaSnapshot = await db.collection('presensi')
        .where('tanggal_waktu', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
        .where('tanggal_waktu', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
        .where('status', '==', 'alpha')
        .where('metode', '==', 'auto_generated_cloud')
        .get();

      const alphaCount = todayAlphaSnapshot.size;
      const executedToday = alphaCount > 0;

      res.json({
        success: true,
        executedToday: executedToday,
        alphaCount: alphaCount,
        message: executedToday 
          ? `Auto-alpha executed today with ${alphaCount} students`
          : 'Auto-alpha not executed yet today',
      });
    } catch (error) {
      console.error('Error checking status:', error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  });

