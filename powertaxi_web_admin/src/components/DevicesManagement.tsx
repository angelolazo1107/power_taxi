import React, { useState, useEffect } from 'react';
import { 
  subscribeToDevices, 
  subscribeToCompanies, 
  addDevice, 
  updateDevice, 
  deleteDevice 
} from '../services/firebase';
import type { Device, Company } from '../services/firebase';
import { 
  Tablet, 
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
  Key
} from 'lucide-react';

interface DevicesManagementProps {
  selectedCompanyId: string | null;
}

export const DevicesManagement: React.FC<DevicesManagementProps> = ({ selectedCompanyId }) => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Dialog & Form states
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingDevice, setEditingDevice] = useState<Device | null>(null);

  const [serialNo, setSerialNo] = useState('');
  const [plateNo, setPlateNo] = useState('');
  const [bodyNo, setBodyNo] = useState('');
  const [ptuNo, setPtuNo] = useState('');
  const [accreditationNo, setAccreditationNo] = useState('');
  const [minNo, setMinNo] = useState('');
  const [tin, setTin] = useState('');
  const [companyId, setCompanyId] = useState('');
  const [companyName, setCompanyName] = useState('');

  // Delete dialog state
  const [deviceToDelete, setDeviceToDelete] = useState<Device | null>(null);

  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; isError: boolean } | null>(null);

  // Subscribe to companies to populate selection dropdown
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
    });
    return () => unsubscribe();
  }, []);

  // Subscribe to real-time device updates (reactive to sidebar filter!)
  useEffect(() => {
    setLoading(true);
    const unsubscribe = subscribeToDevices({ companyId: selectedCompanyId }, (list) => {
      setDevices(list);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [selectedCompanyId]);

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleOpenAdd = () => {
    setEditingDevice(null);
    setSerialNo('');
    setPlateNo('');
    setBodyNo('');
    setPtuNo('');
    setAccreditationNo('');
    setMinNo('');
    setTin('');
    
    // Auto-select company if one is currently filtered
    if (selectedCompanyId) {
      setCompanyId(selectedCompanyId);
      const matched = companies.find(c => c.id === selectedCompanyId);
      setCompanyName(matched ? matched.name : '');
    } else {
      setCompanyId('');
      setCompanyName('');
    }
    
    setIsDialogOpen(true);
  };

  const handleOpenEdit = (d: Device) => {
    setEditingDevice(d);
    setSerialNo(d.serialNo);
    setPlateNo(d.plateNo);
    setBodyNo(d.bodyNo);
    setPtuNo(d.ptuNo);
    setAccreditationNo(d.accreditationNo);
    setMinNo(d.minNo);
    setTin(d.tin);
    setCompanyId(d.companyId || '');
    setCompanyName(d.company);
    setIsDialogOpen(true);
  };

  const handleCompanyChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const id = e.target.value;
    setCompanyId(id);
    const matched = companies.find(c => c.id === id);
    setCompanyName(matched ? matched.name : '');
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanSerial = serialNo.trim().toUpperCase();
    if (!cleanSerial || !companyName) {
      showToast("Serial Number and Company are required.", true);
      return;
    }

    setSaving(true);
    try {
      if (editingDevice) {
        await updateDevice({
          ...editingDevice,
          company: companyName,
          companyId: companyId || null,
          plateNo: plateNo.trim().toUpperCase(),
          bodyNo: bodyNo.trim().toUpperCase(),
          ptuNo: ptuNo.trim(),
          accreditationNo: accreditationNo.trim(),
          minNo: minNo.trim(),
          tin: tin.trim()
        });
        showToast(`Device details for ${cleanSerial} updated successfully!`);
      } else {
        await addDevice({
          serialNo: cleanSerial,
          company: companyName,
          companyId: companyId || null,
          plateNo: plateNo.trim().toUpperCase(),
          bodyNo: bodyNo.trim().toUpperCase(),
          ptuNo: ptuNo.trim(),
          accreditationNo: accreditationNo.trim(),
          minNo: minNo.trim(),
          tin: tin.trim()
        });
        showToast(`New device ${cleanSerial} registered successfully! Default password is '123'.`);
      }
      setIsDialogOpen(false);
    } catch (err: any) {
      showToast(`Error: ${err.message || err}`, true);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deviceToDelete) return;
    try {
      await deleteDevice(deviceToDelete.serialNo);
      showToast(`Deleted device "${deviceToDelete.serialNo}" and revoked user credentials successfully.`);
      setDeviceToDelete(null);
    } catch (err: any) {
      showToast(`Failed to delete device: ${err.message || err}`, true);
    }
  };

  const filteredDevices = devices.filter(d => 
    d.serialNo.toLowerCase().includes(searchQuery.toLowerCase()) ||
    d.plateNo.toLowerCase().includes(searchQuery.toLowerCase()) ||
    d.company.toLowerCase().includes(searchQuery.toLowerCase())
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
          <h1 className="text-xl font-bold text-white">Devices Management</h1>
          <p className="text-xs text-textFaint">
            {selectedCompanyId 
              ? `Showing devices assigned to company filter.`
              : 'All registered physical taxi meter devices and secure client logins.'}
          </p>
        </div>

        <button 
          onClick={handleOpenAdd}
          className="flex items-center justify-center gap-2 bg-accentOrange hover:bg-accentOrange/90 text-black font-extrabold px-5 py-3 rounded-lg text-xs tracking-wide shadow-lg shadow-accentOrange/15 transition-all self-start sm:self-auto"
        >
          <Plus size={16} strokeWidth={2.5} />
          Register Device
        </button>
      </div>

      {/* Summary + Search Row */}
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        {/* Stat Badge */}
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex items-center gap-3 self-start shrink-0">
          <div className="p-2.5 bg-accentOrange/10 rounded-lg text-accentOrange">
            <Tablet size={16} />
          </div>
          <div>
            <span className="text-lg font-black text-white">{devices.length}</span>
            <span className="text-[10px] font-semibold text-textFaint ml-2">Total Active</span>
          </div>
        </div>

        {/* Dynamic filter notice */}
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Filter Active: {companies.find(c => c.id === selectedCompanyId)?.name || 'Filtered'}
          </div>
        )}

        <div className="relative flex-1 max-w-md md:ml-auto w-full">
          <Search className="absolute left-3 top-2.5 text-textFaint" size={15} />
          <input 
            type="text"
            placeholder="Search by serial, plate, or company..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-[#1A1E26] border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange transition-colors"
          />
        </div>
      </div>

      {/* Main Table Directory */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        
        {/* Table Body Area */}
        <div className="flex-1 overflow-y-auto">
          {filteredDevices.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <Tablet className="text-textFaint/20 animate-pulse" size={56} />
              <h4 className="text-sm font-bold text-white/80">No devices found</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">There are no hardware devices matching this search criteria.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-[10px] uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-3.5">Serial No.</th>
                  <th className="px-6 py-3.5">Plate / Body</th>
                  <th className="px-6 py-3.5">Company</th>
                  <th className="px-6 py-3.5">PTU / Accreditation</th>
                  <th className="px-6 py-3.5 text-center w-28">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-xs">
                {filteredDevices.map((d) => (
                  <tr key={d.serialNo} className="hover:bg-cardColor/30 transition-colors">
                    
                    {/* Serial Column */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-borderDark rounded-lg text-white/80">
                          <Tablet size={14} />
                        </div>
                        <div className="flex flex-col">
                          <span className="font-mono font-bold text-white tracking-wider">{d.serialNo}</span>
                          <span className={`text-[9px] mt-0.5 font-bold ${
                            d.status === 'running' 
                              ? 'text-emerald-400' 
                              : d.status === 'idle' 
                                ? 'text-amber-400' 
                                : 'text-textFaint'
                          }`}>
                            ● {d.status.toUpperCase()}
                          </span>
                        </div>
                      </div>
                    </td>

                    {/* Plate Column */}
                    <td className="px-6 py-4">
                      <div className="flex flex-col">
                        <span className="font-semibold text-white/90 font-mono">{d.plateNo || '—'}</span>
                        <span className="text-[10px] text-textFaint">Body: {d.bodyNo || '—'}</span>
                      </div>
                    </td>

                    {/* Company Column */}
                    <td className="px-6 py-4">
                      <span className="text-white/85 font-medium truncate max-w-[150px] block" title={d.company}>
                        {d.company}
                      </span>
                    </td>

                    {/* PTU Column */}
                    <td className="px-6 py-4">
                      <div className="flex flex-col">
                        <span className="text-white/80 font-mono text-[11px]">{d.ptuNo || '—'}</span>
                        <span className="text-[10px] text-textFaint font-mono">{d.accreditationNo || '—'}</span>
                      </div>
                    </td>

                    {/* Actions Column */}
                    <td className="px-6 py-4 w-28">
                      <div className="flex justify-center items-center gap-2">
                        <button 
                          onClick={() => handleOpenEdit(d)}
                          className="p-1.5 hover:bg-borderDark rounded-lg text-textFaint hover:text-white transition-colors border border-transparent hover:border-borderDark"
                          title="Edit Settings"
                        >
                          <Edit3 size={15} />
                        </button>
                        <button 
                          onClick={() => setDeviceToDelete(d)}
                          className="p-1.5 hover:bg-red-950/20 rounded-lg text-red-400 hover:text-red-300 transition-colors border border-transparent hover:border-red-900/30"
                          title="De-register Device"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>

                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

      </div>

      {/* ─── REGISTRATION / EDIT MODAL DIALOG ─────────────────────────────── */}
      {isDialogOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            
            {/* Modal Header */}
            <div className="p-6 border-b border-borderDark flex justify-between items-center shrink-0">
              <div className="flex items-center gap-3">
                <Tablet className="text-accentOrange" size={20} />
                <h3 className="font-extrabold text-base text-white">
                  {editingDevice ? "Edit Taxi Device" : "Register Taxi Device"}
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
              
              {/* Company Selection Dropdown */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Assigned Company *</label>
                <select 
                  required
                  value={companyId}
                  onChange={handleCompanyChange}
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                >
                  <option value="" disabled>-- Select Fleet Company --</option>
                  {companies.map(c => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              {/* Serial No. */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Serial Number (Hardware Key) *</label>
                <input 
                  type="text"
                  required
                  disabled={editingDevice !== null}
                  value={serialNo}
                  onChange={(e) => setSerialNo(e.target.value)}
                  placeholder="e.g. PT-MET-00123"
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors disabled:opacity-50 font-mono uppercase"
                />
                {!editingDevice && (
                  <p className="text-[9px] text-textFaint/80 leading-relaxed flex items-center gap-1.5 mt-1 font-medium">
                    <Key size={10} className="text-accentOrange" />
                    Creates an automatic auth account with default password: <span className="font-extrabold text-white">123</span>
                  </p>
                )}
              </div>

              {/* Grid 1: Plate & Body */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Plate Number</label>
                  <input 
                    type="text"
                    value={plateNo}
                    onChange={(e) => setPlateNo(e.target.value)}
                    placeholder="ABC 1234"
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono uppercase"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Body Number</label>
                  <input 
                    type="text"
                    value={bodyNo}
                    onChange={(e) => setBodyNo(e.target.value)}
                    placeholder="TX-098"
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono uppercase"
                  />
                </div>
              </div>

              {/* PTU Number */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">PTU (Permit to Use) Number</label>
                <input 
                  type="text"
                  value={ptuNo}
                  onChange={(e) => setPtuNo(e.target.value)}
                  placeholder="Enter PTU..."
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono"
                />
              </div>

              {/* Accreditation Number */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Accreditation Number</label>
                <input 
                  type="text"
                  value={accreditationNo}
                  onChange={(e) => setAccreditationNo(e.target.value)}
                  placeholder="Enter BIR accreditation..."
                  className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono"
                />
              </div>

              {/* Grid 2: MIN & TIN */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">MIN Number</label>
                  <input 
                    type="text"
                    value={minNo}
                    onChange={(e) => setMinNo(e.target.value)}
                    placeholder="Enter MIN..."
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Device TIN (BIR)</label>
                  <input 
                    type="text"
                    value={tin}
                    onChange={(e) => setTin(e.target.value)}
                    placeholder="000-000-000-000"
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors font-mono"
                  />
                </div>
              </div>

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
                  {saving ? "Saving..." : editingDevice ? "Save Changes" : "Register Device"}
                </button>
              </div>

            </form>

          </div>
        </div>
      )}

      {/* ─── REMOVE CONFIRMATION DIALOG MODAL ────────────────────────────── */}
      {deviceToDelete && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-sm shadow-2xl p-6 space-y-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex gap-4">
              <div className="p-3 bg-red-950/40 text-red-500 rounded-xl border border-red-900/30 self-start shrink-0">
                <AlertTriangle size={20} />
              </div>
              <div className="space-y-1.5">
                <h4 className="font-extrabold text-sm text-white">De-register Device</h4>
                <p className="text-xs text-textFaint leading-relaxed">
                  Are you sure you want to remove device &ldquo;<span className="text-white font-mono font-semibold">{deviceToDelete.serialNo}</span>&rdquo;? This will immediately revoke physical taxi-meter access and delete the associated login account.
                </p>
              </div>
            </div>

            <div className="flex gap-3 justify-end text-xs">
              <button 
                onClick={() => setDeviceToDelete(null)}
                className="border border-borderDark hover:bg-borderDark/40 text-white font-bold py-2 px-4 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button 
                onClick={handleDelete}
                className="bg-red-600 hover:bg-red-700 text-white font-extrabold py-2 px-4 rounded-lg transition-colors"
              >
                Remove Device
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
