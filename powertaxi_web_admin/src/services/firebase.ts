import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  onSnapshot, 
  doc, 
  updateDoc,
  addDoc,
  deleteDoc,
  query,
  where,
  setDoc,
  serverTimestamp,
  getDocs
} from 'firebase/firestore';
import { getStorage, ref as storageRef, uploadBytes, getDownloadURL } from 'firebase/storage';

const firebaseConfig = {
  apiKey: "AIzaSyAJ8V5izpxXrmAyWcK0OPPEimMflawPavQ",
  authDomain: "powertaxi-metro.firebaseapp.com",
  projectId: "powertaxi-metro",
  storageBucket: "powertaxi-metro.firebasestorage.app",
  messagingSenderId: "333224010311",
  appId: "1:333224010311:web:11ee345e6b5f7f0b218762",
  measurementId: "G-V135CKG2CB"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Data Models
export interface Company {
  id: string;
  name: string;
  tin: string;
  baseFare: number;
  ratePerKm: number;
  ratePerMinute: number;
  distanceMultiplier: number;
  enableShiftFlow?: boolean;
  createdAt?: any;
}

// ─── FIRESTORE SERVICES ──────────────────────────────────────────────────────

/**
 * Stream all transport companies from Firestore in real-time
 */
export const subscribeToCompanies = (onUpdate: (companies: Company[]) => void) => {
  const companiesRef = collection(db, 'companies');
  return onSnapshot(companiesRef, (snapshot) => {
    const list: Company[] = [];
    snapshot.forEach((docSnap) => {
      const data = docSnap.data();
      list.push({
        id: docSnap.id,
        name: data.name || '',
        tin: data.tin || '',
        baseFare: typeof data.baseFare === 'number' ? data.baseFare : 40.0,
        ratePerKm: typeof data.ratePerKm === 'number' ? data.ratePerKm : 13.50,
        ratePerMinute: typeof data.ratePerMinute === 'number' ? data.ratePerMinute : 2.0,
        distanceMultiplier: typeof data.distanceMultiplier === 'number' ? data.distanceMultiplier : 1.0,
        enableShiftFlow: data.enableShiftFlow || false,
        createdAt: data.createdAt
      });
    });
    // Sort companies by name
    list.sort((a, b) => a.name.localeCompare(b.name));
    onUpdate(list);
  }, (err) => {
    console.error("Error fetching companies:", err);
  });
};

/**
 * Update the fare settings of a specific company
 */
export const updateCompanyFareSettings = async (
  companyId: string,
  fareSettings: {
    baseFare: number;
    ratePerKm: number;
    ratePerMinute: number;
    distanceMultiplier: number;
  }
) => {
  const companyDocRef = doc(db, 'companies', companyId);
  await updateDoc(companyDocRef, {
    baseFare: fareSettings.baseFare,
    ratePerKm: fareSettings.ratePerKm,
    ratePerMinute: fareSettings.ratePerMinute,
    distanceMultiplier: fareSettings.distanceMultiplier,
  });
};

/**
 * Add a new company
 */
export const addCompany = async (
  name: string,
  tin: string,
  fareSettings: {
    baseFare?: number;
    ratePerKm?: number;
    ratePerMinute?: number;
    distanceMultiplier?: number;
    enableShiftFlow?: boolean;
  } = {}
) => {
  const companiesRef = collection(db, 'companies');
  await addDoc(companiesRef, {
    name,
    tin,
    baseFare: fareSettings.baseFare ?? 40.0,
    ratePerKm: fareSettings.ratePerKm ?? 13.50,
    ratePerMinute: fareSettings.ratePerMinute ?? 2.0,
    distanceMultiplier: fareSettings.distanceMultiplier ?? 1.0,
    enableShiftFlow: fareSettings.enableShiftFlow ?? false,
    createdAt: new Date()
  });
};

/**
 * Update an existing company (all fields)
 */
export const updateCompany = async (
  companyId: string,
  fields: {
    name: string;
    tin: string;
    baseFare: number;
    ratePerKm: number;
    ratePerMinute: number;
    distanceMultiplier: number;
    enableShiftFlow: boolean;
  }
) => {
  const companyDocRef = doc(db, 'companies', companyId);
  await updateDoc(companyDocRef, {
    name: fields.name,
    tin: fields.tin,
    baseFare: fields.baseFare,
    ratePerKm: fields.ratePerKm,
    ratePerMinute: fields.ratePerMinute,
    distanceMultiplier: fields.distanceMultiplier,
    enableShiftFlow: fields.enableShiftFlow,
  });
};

/**
 * Delete a company
 */
export const deleteCompany = async (companyId: string) => {
  const companyDocRef = doc(db, 'companies', companyId);
  await deleteDoc(companyDocRef);
};

// ─── DEVICES MODELS & SERVICES ──────────────────────────────────────────────

export interface Device {
  serialNo: string;
  company: string;
  companyId: string | null;
  ptuNo: string;
  accreditationNo: string;
  minNo: string;
  tin: string;
  plateNo: string;
  bodyNo: string;
  status: string;
  lastSeen?: any;
  currentDriver?: string | null;
  dailySales: number;
  dailyTripSeconds: number;
  dailyWaitingSeconds: number;
  dailyDistanceMeters: number;
  odometer?: number;
  lastOilChangeOdometer?: number;
  lastTireChangeOdometer?: number;
  needsMaintenance?: boolean;
  maintenanceReason?: string;
  isLocked?: boolean;
  createdAt?: any;
}

/**
 * Stream all taxi meter devices from Firestore in real-time, with optional company scoping
 */
export const subscribeToDevices = (
  filters: { companyId?: string | null; companyName?: string | null },
  onUpdate: (devices: Device[]) => void
) => {
  let devicesRef: any = collection(db, 'devices');
  
  if (filters.companyId) {
    devicesRef = query(devicesRef, where('companyId', '==', filters.companyId));
  } else if (filters.companyName && filters.companyName !== 'All Companies') {
    devicesRef = query(devicesRef, where('company', '==', filters.companyName));
  }

  return onSnapshot(devicesRef, (snapshot: any) => {
    const list: Device[] = [];
    snapshot.forEach((docSnap: any) => {
      const data = docSnap.data();
      list.push({
        serialNo: docSnap.id,
        company: data.company || '',
        companyId: data.companyId || null,
        ptuNo: data.ptuNo || '',
        accreditationNo: data.accreditationNo || '',
        minNo: data.minNo || '',
        tin: data.tin || '',
        plateNo: data.plateNo || '',
        bodyNo: data.bodyNo || '',
        status: data.status || 'offline',
        lastSeen: data.lastSeen,
        currentDriver: data.currentDriver || null,
        dailySales: typeof data.dailySales === 'number' ? data.dailySales : 0.0,
        dailyTripSeconds: typeof data.dailyTripSeconds === 'number' ? data.dailyTripSeconds : 0,
        dailyWaitingSeconds: typeof data.dailyWaitingSeconds === 'number' ? data.dailyWaitingSeconds : 0,
        dailyDistanceMeters: typeof data.dailyDistanceMeters === 'number' ? data.dailyDistanceMeters : 0.0,
        odometer: typeof data.odometer === 'number' ? data.odometer : 0.0,
        lastOilChangeOdometer: typeof data.lastOilChangeOdometer === 'number' ? data.lastOilChangeOdometer : 0.0,
        lastTireChangeOdometer: typeof data.lastTireChangeOdometer === 'number' ? data.lastTireChangeOdometer : 0.0,
        needsMaintenance: data.needsMaintenance || false,
        maintenanceReason: data.maintenanceReason || '',
        isLocked: data.isLocked || false,
        createdAt: data.createdAt
      });
    });
    // Sort in memory by createdAt descending
    list.sort((a, b) => {
      const aTime = a.createdAt?.seconds || 0;
      const bTime = b.createdAt?.seconds || 0;
      return bTime - aTime;
    });
    onUpdate(list);
  }, (err: any) => {
    console.error("Error fetching devices:", err);
  });
};

/**
 * Register a new device in Firestore and automatically create its user account
 */
export const addDevice = async (device: Omit<Device, 'status' | 'dailySales' | 'dailyTripSeconds' | 'dailyWaitingSeconds' | 'dailyDistanceMeters'>) => {
  const cleanSerial = device.serialNo.trim().toUpperCase();
  
  // 1. Create document in 'devices' collection
  const deviceDocRef = doc(db, 'devices', cleanSerial);
  await setDoc(deviceDocRef, {
    serialNo: cleanSerial,
    company: device.company.trim(),
    companyId: device.companyId,
    ptuNo: device.ptuNo.trim(),
    accreditationNo: device.accreditationNo.trim(),
    minNo: device.minNo.trim(),
    tin: device.tin.trim(),
    plateNo: device.plateNo.trim().toUpperCase(),
    bodyNo: device.bodyNo.trim().toUpperCase(),
    status: 'offline',
    lastSeen: null,
    currentDriver: null,
    dailySales: 0.0,
    dailyTripSeconds: 0,
    dailyWaitingSeconds: 0,
    dailyDistanceMeters: 0.0,
    odometer: device.odometer || 0.0,
    lastOilChangeOdometer: device.lastOilChangeOdometer || 0.0,
    lastTireChangeOdometer: device.lastTireChangeOdometer || 0.0,
    needsMaintenance: device.needsMaintenance || false,
    maintenanceReason: device.maintenanceReason || '',
    isLocked: device.isLocked || false,
    createdAt: serverTimestamp()
  });

  // 2. Create associated user document for device authentication
  const userDocRef = doc(db, 'users', cleanSerial);
  await setDoc(userDocRef, {
    email: cleanSerial,
    password: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3", // Hashed default '123'
    role: 'device',
    createdAt: serverTimestamp()
  });
};

/**
 * Update dynamic registration details of a device
 */
export const updateDevice = async (device: Device) => {
  const deviceDocRef = doc(db, 'devices', device.serialNo);
  await setDoc(deviceDocRef, {
    serialNo: device.serialNo,
    company: device.company,
    companyId: device.companyId,
    ptuNo: device.ptuNo,
    accreditationNo: device.accreditationNo,
    minNo: device.minNo,
    tin: device.tin,
    plateNo: device.plateNo,
    bodyNo: device.bodyNo,
    status: device.status,
    lastSeen: device.lastSeen || null,
    currentDriver: device.currentDriver || null,
    dailySales: device.dailySales,
    dailyTripSeconds: device.dailyTripSeconds,
    dailyWaitingSeconds: device.dailyWaitingSeconds,
    dailyDistanceMeters: device.dailyDistanceMeters,
    odometer: device.odometer || 0.0,
    lastOilChangeOdometer: device.lastOilChangeOdometer || 0.0,
    lastTireChangeOdometer: device.lastTireChangeOdometer || 0.0,
    needsMaintenance: device.needsMaintenance || false,
    maintenanceReason: device.maintenanceReason || '',
    isLocked: device.isLocked || false,
    createdAt: device.createdAt || serverTimestamp()
  });
};

/**
 * Remotely lock or unlock a device
 */
export const toggleDeviceLock = async (serialNo: string, isLocked: boolean) => {
  const deviceDocRef = doc(db, 'devices', serialNo);
  await updateDoc(deviceDocRef, { isLocked });
};

/**
 * Delete a device and its associated user authentication record
 */
export const deleteDevice = async (serialNo: string) => {
  const cleanSerial = serialNo.trim().toUpperCase();
  
  // Delete device record
  const deviceDocRef = doc(db, 'devices', cleanSerial);
  await deleteDoc(deviceDocRef);

  // Delete associated user record
  const userDocRef = doc(db, 'users', cleanSerial);
  await deleteDoc(userDocRef);
};

// ─── USER MODELS & SERVICES ──────────────────────────────────────────────────

export interface AppUser {
  id: string;
  email: string;
  password?: string;
  role: string;
  accessibleCompanies: string[];
  name?: string;
  language?: string;
  pin?: string | null;
  photoUrl?: string | null;
  createdAt?: any;
}

/**
 * Utility function to compute a SHA-256 hex digest using Web Crypto API.
 */
export const hashSha256 = async (input: string): Promise<string> => {
  const msgBuffer = new TextEncoder().encode(input);
  const hashBuffer = await window.crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
};

/**
 * Stream all app users from Firestore in real-time, with optional company scoping
 */
export const subscribeToUsers = (
  filters: { companyId?: string | null },
  onUpdate: (users: AppUser[]) => void
) => {
  let usersRef: any = collection(db, 'users');
  
  if (filters.companyId) {
    usersRef = query(usersRef, where('accessibleCompanies', 'array-contains', filters.companyId));
  }

  return onSnapshot(usersRef, (snapshot: any) => {
    const list: AppUser[] = [];
    snapshot.forEach((docSnap: any) => {
      const data = docSnap.data();
      list.push({
        id: docSnap.id,
        email: data.email || '',
        role: data.role || 'user',
        accessibleCompanies: Array.isArray(data.accessibleCompanies) ? data.accessibleCompanies : [],
        name: data.name || '',
        language: data.language || 'English',
        pin: data.pin || null,
        photoUrl: data.photoUrl || null,
        createdAt: data.createdAt
      });
    });
    // Sort in memory by createdAt descending
    list.sort((a, b) => {
      const aTime = a.createdAt?.seconds || 0;
      const bTime = b.createdAt?.seconds || 0;
      return bTime - aTime;
    });
    onUpdate(list);
  }, (err: any) => {
    console.error("Error fetching users:", err);
  });
};

/**
 * Register a new user account in Firestore (automatically hashes passwords/PINs)
 */
export const addUser = async (user: Omit<AppUser, 'id'>): Promise<string> => {
  const usersRef = collection(db, 'users');
  const docRef = await addDoc(usersRef, {
    email: user.email.trim(),
    password: user.password || "ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f", // Default hashed 'password123'
    role: user.role,
    accessibleCompanies: user.accessibleCompanies,
    name: user.name?.trim() || '',
    language: user.language || 'English',
    pin: user.pin || null,
    photoUrl: user.photoUrl || null,
    createdAt: serverTimestamp()
  });
  return docRef.id;
};

/**
 * Update an existing user account
 */
export const updateUser = async (user: AppUser) => {
  const userDocRef = doc(db, 'users', user.id);
  await updateDoc(userDocRef, {
    email: user.email.trim(),
    role: user.role,
    accessibleCompanies: user.accessibleCompanies,
    name: user.name?.trim() || '',
    language: user.language || 'English',
    pin: user.pin || null,
    photoUrl: user.photoUrl || null,
  });
};

/**
 * Upload a driver profile photo to Firebase Storage and get download URL
 */
export const uploadDriverPhoto = async (userId: string, file: File): Promise<string> => {
  const fileRef = storageRef(storage, `drivers/${userId}/${Date.now()}_${file.name}`);
  await uploadBytes(fileRef, file);
  return getDownloadURL(fileRef);
};

/**
 * Delete a user account from Firestore
 */
export const deleteUser = async (userId: string) => {
  const userDocRef = doc(db, 'users', userId);
  await deleteDoc(userDocRef);
};

// ─── RIDE RECORD MODELS & SERVICES ───────────────────────────────────────────

export interface RideRecord {
  id: string;
  driverId: string;
  companyId: string | null;
  startTime: string; // ISO 8601 string
  endTime?: string | null; // ISO 8601 string
  distanceMeters: number;
  totalFare: number;
  status: string; // 'running', 'completed', 'unknown', etc.
  grossFare?: number;
  discountType?: string;
  discountAmount?: number;
  deviceSerialNo?: string;
  plateNo?: string;
  bodyNo?: string;
  orNumber?: string;
  lastUpdatedAt?: string;
}

/**
 * Stream all active (running) taxi trips in real-time
 */
export const subscribeToActiveRides = (
  filters: { companyId?: string | null },
  onUpdate: (rides: RideRecord[]) => void
) => {
  let ridesRef: any = collection(db, 'rides');
  
  // Get active (running) rides
  ridesRef = query(ridesRef, where('status', '==', 'running'));

  if (filters.companyId) {
    ridesRef = query(ridesRef, where('companyId', '==', filters.companyId));
  }

  return onSnapshot(ridesRef, (snapshot: any) => {
    const list: RideRecord[] = [];
    snapshot.forEach((docSnap: any) => {
      const data = docSnap.data();
      list.push({
        id: docSnap.id,
        driverId: data.driverId || '',
        companyId: data.companyId || null,
        startTime: data.startTime || '',
        endTime: data.endTime || null,
        distanceMeters: typeof data.distanceMeters === 'number' ? data.distanceMeters : 0.0,
        totalFare: typeof data.totalFare === 'number' ? data.totalFare : 0.0,
        status: data.status || 'unknown',
        grossFare: typeof data.grossFare === 'number' ? data.grossFare : undefined,
        discountType: data.discountType || undefined,
        discountAmount: typeof data.discountAmount === 'number' ? data.discountAmount : undefined,
        deviceSerialNo: data.deviceSerialNo || undefined,
        plateNo: data.plateNo || undefined,
        bodyNo: data.bodyNo || undefined,
        orNumber: data.orNumber || undefined,
        lastUpdatedAt: data.lastUpdatedAt || undefined,
      });
    });
    onUpdate(list);
  }, (err: any) => {
    console.error("Error fetching active rides:", err);
  });
};

/**
 * Stream all historic and current taxi trips in real-time
 */
export const subscribeToAllRides = (
  filters: { companyId?: string | null },
  onUpdate: (rides: RideRecord[]) => void
) => {
  let ridesRef: any = collection(db, 'rides');

  if (filters.companyId) {
    ridesRef = query(ridesRef, where('companyId', '==', filters.companyId));
  }

  return onSnapshot(ridesRef, (snapshot: any) => {
    const list: RideRecord[] = [];
    snapshot.forEach((docSnap: any) => {
      const data = docSnap.data();
      list.push({
        id: docSnap.id,
        driverId: data.driverId || '',
        companyId: data.companyId || null,
        startTime: data.startTime || '',
        endTime: data.endTime || null,
        distanceMeters: typeof data.distanceMeters === 'number' ? data.distanceMeters : 0.0,
        totalFare: typeof data.totalFare === 'number' ? data.totalFare : 0.0,
        status: data.status || 'unknown',
        grossFare: typeof data.grossFare === 'number' ? data.grossFare : undefined,
        discountType: data.discountType || undefined,
        discountAmount: typeof data.discountAmount === 'number' ? data.discountAmount : undefined,
        deviceSerialNo: data.deviceSerialNo || undefined,
        plateNo: data.plateNo || undefined,
        bodyNo: data.bodyNo || undefined,
        orNumber: data.orNumber || undefined,
        lastUpdatedAt: data.lastUpdatedAt || undefined,
      });
    });
    // Sort in memory by startTime descending (newest first)
    list.sort((a, b) => b.startTime.localeCompare(a.startTime));
    onUpdate(list);
  }, (err: any) => {
    console.error("Error fetching all rides:", err);
  });
};

/**
 * Authenticate an administrative or operator user against Firestore.
 * Supports comparing both plain-text passwords and secure SHA-256 hashes.
 */
export const authenticateUser = async (email: string, passwordPlain: string): Promise<AppUser> => {
  const cleanEmail = email.trim().toLowerCase();
  const q = query(
    collection(db, 'users'),
    where('email', '==', cleanEmail),
    where('role', 'in', ['admin', 'operator'])
  );

  const querySnapshot = await getDocs(q);
  if (querySnapshot.empty) {
    throw new Error('Invalid email or password');
  }

  const userDoc = querySnapshot.docs[0];
  const userData = userDoc.data();
  const storedPassword = userData.password || '';

  // Compute secure SHA-256 hash of the plain-text input to compare
  const enteredHash = await hashSha256(passwordPlain);

  if (storedPassword !== passwordPlain && storedPassword !== enteredHash) {
    throw new Error('Invalid email or password');
  }

  return {
    id: userDoc.id,
    email: userData.email || cleanEmail,
    role: userData.role || 'operator',
    accessibleCompanies: Array.isArray(userData.accessibleCompanies) ? userData.accessibleCompanies : [],
    name: userData.name || '',
    language: userData.language || 'English',
    pin: userData.pin || null,
  };
};
