import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { 
  subscribeToUsers, 
  subscribeToCompanies, 
  addUser, 
  updateUser, 
  deleteUser,
  hashSha256,
  uploadDriverPhoto,
  db
} from '../services/firebase';
import type { AppUser, Company } from '../services/firebase';
import { 
  Users, 
  Plus, 
  Search, 
  Edit3, 
  Trash2, 
  AlertTriangle, 
  X, 
  Save,
  CheckCircle,
  AlertCircle,
  Building,
  Shield,
  UserCheck,
  Camera
} from 'lucide-react';

interface UserManagementProps {
  selectedCompanyId: string | null;
}

export const UserManagement: React.FC<UserManagementProps> = ({ selectedCompanyId }) => {
  const [users, setUsers] = useState<AppUser[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Dialog & Form states
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<AppUser | null>(null);

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('driver');
  const [language, setLanguage] = useState('English');
  const [pin, setPin] = useState('');
  const [selectedCompanies, setSelectedCompanies] = useState<string[]>([]);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);

  // Delete dialog state
  const [userToDelete, setUserToDelete] = useState<AppUser | null>(null);

  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; isError: boolean } | null>(null);

  // Subscribe to companies to resolve company names
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
    });
    return () => unsubscribe();
  }, []);

  // Subscribe to users (reactive to dynamic sidebar company selection!)
  useEffect(() => {
    setLoading(true);
    const unsubscribe = subscribeToUsers({ companyId: selectedCompanyId }, (list) => {
      setUsers(list);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [selectedCompanyId]);

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleOpenAdd = () => {
    setEditingUser(null);
    setName('');
    setEmail('');
    setRole('driver');
    setLanguage('English');
    setPin('');
    setPhotoFile(null);
    setPhotoUrl(null);
    
    // Auto-select company if one is filtered in the sidebar
    if (selectedCompanyId) {
      setSelectedCompanies([selectedCompanyId]);
    } else {
      setSelectedCompanies([]);
    }
    
    setIsDialogOpen(true);
  };

  const handleOpenEdit = (u: AppUser) => {
    setEditingUser(u);
    setName(u.name || '');
    setEmail(u.email);
    setRole(u.role);
    setLanguage(u.language || 'English');
    setPin(''); // Pin remains hidden / unchanged unless re-entered
    setSelectedCompanies(u.accessibleCompanies || []);
    setPhotoFile(null);
    setPhotoUrl(u.photoUrl || null);
    setIsDialogOpen(true);
  };

  const handleCompanyToggle = (compId: string) => {
    if (selectedCompanies.includes(compId)) {
      setSelectedCompanies(selectedCompanies.filter(id => id !== compId));
    } else {
      setSelectedCompanies([...selectedCompanies, compId]);
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !email.trim()) {
      showToast("Name and Email are required.", true);
      return;
    }

    // PIN validation and duplicate check for drivers
    if (role === 'driver') {
      const pinVal = pin.trim();
      const needsPinCheck = editingUser ? pinVal.length > 0 : true;
      const pinToCheck = pinVal || '123456';

      if (needsPinCheck) {
        if (pinToCheck.length !== 6) {
          showToast("PIN must be exactly 6 digits.", true);
          return;
        }

        setSaving(true);
        try {
          const hashedPinToCheck = await hashSha256(pinToCheck);
          const usersRef = collection(db, 'users');
          
          // Check for duplicate hashed PIN
          const qHashed = query(
            usersRef, 
            where('role', '==', 'driver'), 
            where('pin', '==', hashedPinToCheck)
          );
          // Check for duplicate plain text PIN
          const qPlain = query(
            usersRef, 
            where('role', '==', 'driver'), 
            where('pin', '==', pinToCheck)
          );

          const [hashedSnap, plainSnap] = await Promise.all([
            getDocs(qHashed),
            getDocs(qPlain)
          ]);

          let duplicateUser: any = null;
          hashedSnap.forEach((docSnap) => {
            if (!editingUser || docSnap.id !== editingUser.id) {
              duplicateUser = docSnap.data();
            }
          });
          plainSnap.forEach((docSnap) => {
            if (!editingUser || docSnap.id !== editingUser.id) {
              duplicateUser = docSnap.data();
            }
          });

          if (duplicateUser) {
            showToast(`PIN is already assigned to driver "${duplicateUser.name || duplicateUser.email}". Please choose a unique PIN.`, true);
            setSaving(false);
            return;
          }
        } catch (err: any) {
          showToast(`Error validating PIN: ${err.message || err}`, true);
          setSaving(false);
          return;
        }
      }
    }

    setSaving(true);
    try {
      let finalPin = editingUser?.pin || null;

      // Hash PIN if provided (only for drivers)
      if (role === 'driver' && pin.trim()) {
        finalPin = await hashSha256(pin.trim());
      } else if (role !== 'driver') {
        finalPin = null;
      }

      if (editingUser) {
        let currentPhotoUrl = photoUrl;
        if (photoFile) {
          showToast("Uploading profile picture...");
          currentPhotoUrl = await uploadDriverPhoto(editingUser.id, photoFile);
        }
        await updateUser({
          ...editingUser,
          email: email.trim(),
          role,
          accessibleCompanies: selectedCompanies,
          name: name.trim(),
          language,
          pin: finalPin,
          photoUrl: currentPhotoUrl
        });
        showToast(`User account for "${name}" updated successfully!`);
      } else {
        // If driver is added without PIN, warn or set default '123456'
        let hashedPin = null;
        if (role === 'driver') {
          const pinVal = pin.trim() || '123456';
          hashedPin = await hashSha256(pinVal);
        }

        const newUserId = await addUser({
          email: email.trim(),
          role,
          accessibleCompanies: selectedCompanies,
          name: name.trim(),
          language,
          pin: hashedPin,
          photoUrl: null
        });

        if (photoFile) {
          showToast("Uploading profile picture...");
          const uploadedUrl = await uploadDriverPhoto(newUserId, photoFile);
          // Update the newly created user with the photoUrl
          await updateUser({
            id: newUserId,
            email: email.trim(),
            role,
            accessibleCompanies: selectedCompanies,
            name: name.trim(),
            language,
            pin: hashedPin,
            photoUrl: uploadedUrl
          });
        }
        showToast(`New user registered! Default password: 'password123'${role === 'driver' ? ", PIN: " + (pin.trim() || '123456') : ""}.`);
      }
      setIsDialogOpen(false);
    } catch (err: any) {
      showToast(`Error: ${err.message || err}`, true);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!userToDelete) return;
    try {
      await deleteUser(userToDelete.id);
      showToast(`Deleted user account "${userToDelete.name || userToDelete.email}" permanently.`);
      setUserToDelete(null);
    } catch (err: any) {
      showToast(`Failed to delete user: ${err.message || err}`, true);
    }
  };

  const getRoleTheme = (roleName: string) => {
    switch (roleName) {
      case 'admin':
        return 'bg-purple-950/40 border-purple-800 text-purple-300';
      case 'manager':
        return 'bg-cyan-950/40 border-cyan-800 text-cyan-300';
      case 'driver':
        return 'bg-blue-950/40 border-blue-800 text-blue-300';
      case 'user':
        return 'bg-emerald-950/40 border-emerald-800 text-emerald-300';
      default:
        return 'bg-gray-950/40 border-gray-800 text-gray-400';
    }
  };

  const getCompanyNamesString = (compIds: string[]) => {
    if (!compIds || compIds.length === 0) return 'No Access';
    const names = compIds.map(id => {
      const match = companies.find(c => c.id === id);
      return match ? match.name : 'Unknown';
    });
    return names.join(', ');
  };

  const filteredUsers = users.filter(u => 
    (u.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    u.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    u.role.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accentOrange border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6 flex flex-col h-full overflow-y-auto relative">
      
      {/* Toast Alert */}
      {toast && (
        <div className={`fixed bottom-6 right-6 flex items-center gap-3 px-4 py-3 rounded-lg shadow-lg border z-50 transition-all animate-bounce ${
          toast.isError ? 'bg-red-950 border-red-800 text-red-300' : 'bg-emerald-950 border-emerald-800 text-emerald-300'
        }`}>
          {toast.isError ? <AlertCircle size={18} /> : <CheckCircle size={18} />}
          <span className="font-semibold text-sm">{toast.message}</span>
        </div>
      )}

      {/* Header Panel */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white">Users Management</h1>
          <p className="text-xs text-textFaint">
            {selectedCompanyId 
              ? 'Showing staff and drivers with authorized company access.'
              : 'Administer all operators, drivers, managers, and system profiles.'}
          </p>
        </div>

        <button 
          onClick={handleOpenAdd}
          className="flex items-center justify-center gap-2 bg-accentOrange hover:bg-accentOrange/90 text-black font-extrabold px-5 py-3 rounded-lg text-xs tracking-wide shadow-lg shadow-accentOrange/15 transition-all self-start sm:self-auto"
        >
          <Plus size={16} strokeWidth={2.5} />
          Add User
        </button>
      </div>

      {/* Summary + Search Row */}
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        {/* Stat Badge */}
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex items-center gap-3 self-start shrink-0">
          <div className="p-2.5 bg-accentOrange/10 rounded-lg text-accentOrange">
            <Users size={16} />
          </div>
          <div>
            <span className="text-lg font-black text-white">{users.length}</span>
            <span className="text-[10px] font-semibold text-textFaint ml-2">Total Accounts</span>
          </div>
        </div>

        {/* Scoping Filter Tag */}
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Access Filter: {companies.find(c => c.id === selectedCompanyId)?.name || 'Filtered'}
          </div>
        )}

        <div className="relative flex-1 max-w-md md:ml-auto w-full">
          <Search className="absolute left-3 top-2.5 text-textFaint" size={15} />
          <input 
            type="text"
            placeholder="Search by name, email, or role..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-[#1A1E26] border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange transition-colors"
          />
        </div>
      </div>

      {/* Main Table Directory */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        
        {/* Table Body */}
        <div className="flex-1 overflow-y-auto">
          {filteredUsers.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <Users className="text-textFaint/20 animate-pulse" size={56} />
              <h4 className="text-sm font-bold text-white/80">No users found</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">There are no operational profiles matching this filter.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-[10px] uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-3.5">Name</th>
                  <th className="px-6 py-3.5">Email Address</th>
                  <th className="px-6 py-3.5">Role</th>
                  <th className="px-6 py-3.5">Accessible Companies</th>
                  <th className="px-6 py-3.5 text-center w-28">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-xs">
                {filteredUsers.map((u) => {
                  const initial = (u.name || u.email || '?').substring(0, 1).toUpperCase();
                  return (
                    <tr key={u.id} className="hover:bg-cardColor/30 transition-colors">
                      
                      {/* Name Column */}
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          {u.photoUrl ? (
                            <img 
                              src={u.photoUrl} 
                              alt={u.name || 'Profile'} 
                              className="w-8 h-8 rounded-full object-cover border border-accentOrange/25"
                            />
                          ) : (
                            <div className="w-8 h-8 rounded-full bg-accentOrange/10 border border-accentOrange/25 flex items-center justify-center text-accentOrange font-extrabold text-xs">
                              {initial}
                            </div>
                          )}
                          <span className="font-semibold text-white/95">{u.name || '—'}</span>
                        </div>
                      </td>

                      {/* Email Column */}
                      <td className="px-6 py-4 font-medium text-white/80">
                        {u.email}
                      </td>

                      {/* Role Badge */}
                      <td className="px-6 py-4">
                        <span className={`px-2.5 py-1 rounded-md text-[9px] font-bold border ${getRoleTheme(u.role)} uppercase tracking-wider`}>
                          {u.role}
                        </span>
                      </td>

                      {/* Accessible Companies Column */}
                      <td className="px-6 py-4 text-white/75 truncate max-w-[200px]" title={getCompanyNamesString(u.accessibleCompanies)}>
                        {getCompanyNamesString(u.accessibleCompanies)}
                      </td>

                      {/* Actions */}
                      <td className="px-6 py-4 w-28">
                        <div className="flex justify-center items-center gap-2">
                          <button 
                            onClick={() => handleOpenEdit(u)}
                            className="p-1.5 hover:bg-borderDark rounded-lg text-textFaint hover:text-white transition-colors border border-transparent hover:border-borderDark"
                            title="Edit Settings"
                          >
                            <Edit3 size={15} />
                          </button>
                          <button 
                            onClick={() => setUserToDelete(u)}
                            className="p-1.5 hover:bg-red-950/20 rounded-lg text-red-400 hover:text-red-300 transition-colors border border-transparent hover:border-red-900/30"
                            title="Delete User"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </td>

                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

      </div>

      {/* ─── ADD/EDIT USER MODAL DIALOG ──────────────────────────────────── */}
      {isDialogOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            
            {/* Modal Header */}
            <div className="p-6 border-b border-borderDark flex justify-between items-center shrink-0">
              <div className="flex items-center gap-3">
                <Users className="text-accentOrange" size={20} />
                <h3 className="font-extrabold text-base text-white">
                  {editingUser ? "Edit User Account" : "Add User Account"}
                </h3>
              </div>
              <button 
                onClick={() => setIsDialogOpen(false)}
                className="p-1 text-textFaint hover:text-white hover:bg-borderDark/40 rounded-lg transition-all"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSave} className="flex-1 overflow-y-auto p-6 space-y-5">
              
              {/* Profile Photo Uploader */}
              <div className="flex flex-col items-center justify-center space-y-3 pb-3 border-b border-borderDark/40">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">Profile Photo</label>
                <div className="relative group w-20 h-20 rounded-full overflow-hidden border-2 border-accentOrange/30 hover:border-accentOrange transition-all cursor-pointer bg-[#1A1E26] flex items-center justify-center shadow-lg">
                  {photoFile ? (
                    <img 
                      src={URL.createObjectURL(photoFile)} 
                      alt="Preview" 
                      className="w-full h-full object-cover" 
                    />
                  ) : photoUrl ? (
                    <img 
                      src={photoUrl} 
                      alt="Profile" 
                      className="w-full h-full object-cover" 
                    />
                  ) : (
                    <Camera className="text-textFaint/40 w-8 h-8 group-hover:scale-105 transition-transform" />
                  )}
                  <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
                    <span className="text-[9px] text-white font-extrabold tracking-wide uppercase">Upload</span>
                  </div>
                  <input 
                    type="file" 
                    accept="image/*" 
                    onChange={(e) => {
                      if (e.target.files && e.target.files[0]) {
                        setPhotoFile(e.target.files[0]);
                      }
                    }}
                    className="absolute inset-0 opacity-0 cursor-pointer" 
                  />
                </div>
                {(photoFile || photoUrl) && (
                  <button 
                    type="button" 
                    onClick={() => {
                      setPhotoFile(null);
                      setPhotoUrl(null);
                    }}
                    className="text-[9px] font-bold text-red-400 hover:text-red-300 transition-colors uppercase tracking-wider"
                  >
                    Remove Photo
                  </button>
                )}
              </div>
              
              {/* Name */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Full Name *</label>
                <input 
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. John Doe"
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors"
                />
              </div>

              {/* Email */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Email Address *</label>
                <input 
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="e.g. johndoe@powertaxi.com"
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors"
                />
              </div>

              {/* Grid: Role & Language */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Access Role</label>
                  <select 
                    value={role}
                    onChange={(e) => setRole(e.target.value)}
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                  >
                    <option value="driver">Driver</option>
                    <option value="admin">Admin</option>
                    <option value="manager">Manager</option>
                    <option value="user">User</option>
                  </select>
                </div>
                
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">System Language</label>
                  <select 
                    value={language}
                    onChange={(e) => setLanguage(e.target.value)}
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                  >
                    <option value="English">English</option>
                    <option value="Spanish">Spanish</option>
                    <option value="Tagalog">Tagalog</option>
                  </select>
                </div>
              </div>

              {/* Company Permissions Multiple Bind */}
              <div className="space-y-2">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">Authorized Company Access</label>
                <div className="grid grid-cols-2 gap-2 max-h-32 overflow-y-auto p-3 bg-cardColor border border-borderDark rounded-lg">
                  {companies.map(c => {
                    const isChecked = selectedCompanies.includes(c.id);
                    return (
                      <label key={c.id} className="flex items-center gap-2.5 text-xs text-white/80 cursor-pointer hover:text-white transition-colors">
                        <input 
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => handleCompanyToggle(c.id)}
                          className="rounded border-borderDark text-accentOrange bg-bg focus:ring-accentOrange h-3.5 w-3.5 cursor-pointer accent-accentOrange"
                        />
                        <span className="truncate">{c.name}</span>
                      </label>
                    );
                  })}
                </div>
              </div>

              {/* Specialized PIN for Drivers */}
              {role === 'driver' && (
                <div className="p-4 bg-borderDark/40 border border-borderDark rounded-xl space-y-3">
                  <div className="flex items-center gap-2 text-accentOrange text-xs font-bold">
                    <Shield size={14} />
                    Driver Login Authentication
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[9px] font-bold text-textFaint uppercase tracking-wider block">6-Digit Login PIN</label>
                    <input 
                      type="password"
                      maxLength={6}
                      pattern="[0-9]*"
                      inputMode="numeric"
                      value={pin}
                      onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
                      placeholder={editingUser ? "•••••• (Unchanged)" : "e.g. 123456"}
                      className="w-32 tracking-[8px] font-bold px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors text-center"
                    />
                    <p className="text-[9px] text-textFaint leading-relaxed mt-1">
                      {editingUser 
                        ? "Leave empty to keep current PIN. Enter exactly 6 digits to update."
                        : "Required. This PIN will be securely hashed with SHA-256 for mobile terminals."}
                    </p>
                  </div>
                </div>
              )}

              {/* Add Notice */}
              {!editingUser && (
                <p className="text-[9px] text-textFaint leading-relaxed flex items-center gap-1.5 mt-1 font-semibold">
                  <UserCheck size={11} className="text-accentOrange shrink-0" />
                  Initial default password for web logins is set to: <span className="font-extrabold text-white">password123</span>
                </p>
              )}

              {/* Footer Actions */}
              <div className="pt-4 flex gap-3 shrink-0">
                <button 
                  type="button"
                  onClick={() => setIsDialogOpen(false)}
                  disabled={saving}
                  className="flex-1 border border-borderDark hover:bg-borderDark/40 text-white font-bold py-2.5 px-4 rounded-xl disabled:opacity-50 text-xs transition-colors"
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  disabled={saving}
                  className="flex-1 flex items-center justify-center gap-2 bg-accentOrange hover:bg-accentOrange/90 text-black font-extrabold py-2.5 px-4 rounded-xl disabled:opacity-50 text-xs transition-colors"
                >
                  <Save size={14} />
                  {saving ? "Saving..." : editingUser ? "Save Changes" : "Create User"}
                </button>
              </div>

            </form>

          </div>
        </div>
      )}

      {/* ─── DELETE USER CONFIRMATION DIALOG ─────────────────────────────── */}
      {userToDelete && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-sm shadow-2xl p-6 space-y-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex gap-4">
              <div className="p-3 bg-red-950/40 text-red-500 rounded-xl border border-red-900/30 self-start shrink-0">
                <AlertTriangle size={20} />
              </div>
              <div className="space-y-1.5">
                <h4 className="font-extrabold text-sm text-white">Delete User Account</h4>
                <p className="text-xs text-textFaint leading-relaxed">
                  Are you sure you want to permanently delete &ldquo;<span className="text-white font-semibold">{userToDelete.name || userToDelete.email}</span>&rdquo;? This operator or driver will immediately lose all login access to the system.
                </p>
              </div>
            </div>

            <div className="flex gap-3 justify-end text-xs">
              <button 
                onClick={() => setUserToDelete(null)}
                className="border border-borderDark hover:bg-borderDark/40 text-white font-bold py-2 px-4 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button 
                onClick={handleDelete}
                className="bg-red-600 hover:bg-red-700 text-white font-extrabold py-2 px-4 rounded-lg transition-colors"
              >
                Delete Account
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
