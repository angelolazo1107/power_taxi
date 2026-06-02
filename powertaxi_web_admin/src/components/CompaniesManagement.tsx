import React, { useState, useEffect } from 'react';
import { 
  subscribeToCompanies, 
  addCompany, 
  updateCompany, 
  deleteCompany 
} from '../services/firebase';
import type { Company } from '../services/firebase';
import { 
  Building, 
  Plus, 
  Search, 
  Edit3, 
  Trash2, 
  AlertTriangle, 
  X, 
  Save,
  CheckCircle,
  AlertCircle
} from 'lucide-react';

export const CompaniesManagement: React.FC = () => {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Dialog & Form states
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingCompany, setEditingCompany] = useState<Company | null>(null);
  
  const [name, setName] = useState('');
  const [tin, setTin] = useState('');
  const [baseFare, setBaseFare] = useState('40.0');
  const [ratePerKm, setRatePerKm] = useState('13.50');
  const [ratePerMinute, setRatePerMinute] = useState('2.00');
  const [distanceMultiplier, setDistanceMultiplier] = useState('1.00');

  // Delete dialog state
  const [companyToDelete, setCompanyToDelete] = useState<Company | null>(null);

  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; isError: boolean } | null>(null);

  // Subscribe to real-time company updates
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleOpenAdd = () => {
    setEditingCompany(null);
    setName('');
    setTin('');
    setBaseFare('40.0');
    setRatePerKm('13.50');
    setRatePerMinute('2.00');
    setDistanceMultiplier('1.00');
    setIsDialogOpen(true);
  };

  const handleOpenEdit = (c: Company) => {
    setEditingCompany(c);
    setName(c.name);
    setTin(c.tin);
    setBaseFare(c.baseFare.toString());
    setRatePerKm(c.ratePerKm.toString());
    setRatePerMinute(c.ratePerMinute.toString());
    setDistanceMultiplier(c.distanceMultiplier.toString());
    setIsDialogOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setSaving(true);
    try {
      const fareFields = {
        baseFare: parseFloat(baseFare) || 40.0,
        ratePerKm: parseFloat(ratePerKm) || 13.50,
        ratePerMinute: parseFloat(ratePerMinute) || 2.0,
        distanceMultiplier: parseFloat(distanceMultiplier) || 1.0,
      };

      if (editingCompany) {
        await updateCompany(editingCompany.id, {
          name,
          tin,
          ...fareFields
        });
        showToast("Company details updated successfully!");
      } else {
        await addCompany(name, tin, fareFields);
        showToast("New company registered successfully!");
      }
      setIsDialogOpen(false);
    } catch (err: any) {
      showToast(`Error: ${err.message || err}`, true);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!companyToDelete) return;
    try {
      await deleteCompany(companyToDelete.id);
      showToast(`Deleted company "${companyToDelete.name}" successfully.`);
      setCompanyToDelete(null);
    } catch (err: any) {
      showToast(`Failed to delete company: ${err.message || err}`, true);
    }
  };

  const filteredCompanies = companies.filter(c => 
    c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.tin.toLowerCase().includes(searchQuery.toLowerCase())
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
          <h1 className="text-xl font-bold text-white">Companies Management</h1>
          <p className="text-xs text-textFaint">Register and administer transport companies under the fleet system.</p>
        </div>

        <button 
          onClick={handleOpenAdd}
          className="flex items-center justify-center gap-2 bg-accentOrange hover:bg-accentOrange/90 text-black font-extrabold px-5 py-3 rounded-lg text-xs tracking-wide shadow-lg shadow-accentOrange/15 transition-all self-start sm:self-auto"
        >
          <Plus size={16} strokeWidth={2.5} />
          Add Company
        </button>
      </div>

      {/* Stat Card */}
      <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 self-start">
        <div className="p-3 bg-accentOrange/10 rounded-xl text-accentOrange">
          <Building size={20} />
        </div>
        <div>
          <span className="text-2xl font-black text-white">{companies.length}</span>
          <span className="text-xs font-semibold text-textFaint ml-2.5">Total Companies</span>
        </div>
      </div>

      {/* Search and Table Container */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        
        {/* Table Filter Top Bar */}
        <div className="p-5 border-b border-borderDark flex justify-between items-center shrink-0">
          <h3 className="font-bold text-sm text-white/90">Registered List</h3>
          <div className="relative">
            <Search className="absolute left-3 top-2.5 text-textFaint" size={15} />
            <input 
              type="text"
              placeholder="Search by name or TIN..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2 bg-[#1A1E26] border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange w-60 transition-colors"
            />
          </div>
        </div>

        {/* Table Body Area */}
        <div className="flex-1 overflow-y-auto">
          {filteredCompanies.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <Building className="text-textFaint/20 animate-pulse" size={56} />
              <h4 className="text-sm font-bold text-white/80">No companies found</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">There are no transport companies meeting this filter description.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-[10px] uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-3.5">Company Name</th>
                  <th className="px-6 py-3.5">TIN Number</th>
                  <th className="px-6 py-3.5 text-center w-28">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-xs">
                {filteredCompanies.map((c) => (
                  <tr key={c.id} className="hover:bg-cardColor/30 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-borderDark rounded-lg text-white/80">
                          <Building size={14} />
                        </div>
                        <span className="font-semibold text-white/90">{c.name}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 font-mono text-white/70">
                      {c.tin || '—'}
                    </td>
                    <td className="px-6 py-4 w-28">
                      <div className="flex justify-center items-center gap-2">
                        <button 
                          onClick={() => handleOpenEdit(c)}
                          className="p-1.5 hover:bg-borderDark rounded-lg text-textFaint hover:text-white transition-colors border border-transparent hover:border-borderDark"
                          title="Edit Details"
                        >
                          <Edit3 size={15} />
                        </button>
                        <button 
                          onClick={() => setCompanyToDelete(c)}
                          className="p-1.5 hover:bg-red-950/20 rounded-lg text-red-400 hover:text-red-300 transition-colors border border-transparent hover:border-red-900/30"
                          title="Delete Company"
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

      {/* ─── ADD/EDIT DIALOG MODAL ────────────────────────────────────────── */}
      {isDialogOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-md shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            
            {/* Modal Header */}
            <div className="p-6 border-b border-borderDark flex justify-between items-center shrink-0">
              <div className="flex items-center gap-3">
                <Building className="text-accentOrange" size={20} />
                <h3 className="font-extrabold text-base text-white">
                  {editingCompany ? "Edit Company" : "Add Company"}
                </h3>
              </div>
              <button 
                onClick={() => setIsDialogOpen(false)}
                className="p-1 text-textFaint hover:text-white hover:bg-borderDark/40 rounded-lg transition-all"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Form Content */}
            <form onSubmit={handleSave} className="flex-1 overflow-y-auto p-6 space-y-6">
              
              {/* Basic Fields */}
              <div className="space-y-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">Company Name</label>
                  <input 
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Enter transport name..."
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors"
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider">TIN Number</label>
                  <input 
                    type="text"
                    value={tin}
                    onChange={(e) => setTin(e.target.value)}
                    placeholder="Enter business TIN..."
                    className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange transition-colors"
                  />
                </div>
              </div>

              {/* Divider */}
              <div className="border-t border-borderDark my-2"></div>

              {/* Calibration Fields */}
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-accentOrange font-bold text-xs shrink-0">
                  <SlidersIcon />
                  Calibration Settings
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-textFaint uppercase">Base Fare</label>
                    <input 
                      type="number"
                      step="0.1"
                      required
                      value={baseFare}
                      onChange={(e) => setBaseFare(e.target.value)}
                      className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-textFaint uppercase">Rate / KM</label>
                    <input 
                      type="number"
                      step="0.05"
                      required
                      value={ratePerKm}
                      onChange={(e) => setRatePerKm(e.target.value)}
                      className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-textFaint uppercase">Rate / Min</label>
                    <input 
                      type="number"
                      step="0.05"
                      required
                      value={ratePerMinute}
                      onChange={(e) => setRatePerMinute(e.target.value)}
                      className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-textFaint uppercase">Dist Multiplier</label>
                    <input 
                      type="number"
                      step="0.01"
                      required
                      value={distanceMultiplier}
                      onChange={(e) => setDistanceMultiplier(e.target.value)}
                      className="w-full px-4 py-2.5 bg-cardColor border border-borderDark rounded-lg text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                    />
                  </div>
                </div>
              </div>

              {/* Actions Footer inside form scroll */}
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
                  {saving ? "Saving..." : editingCompany ? "Save Changes" : "Add Company"}
                </button>
              </div>

            </form>

          </div>
        </div>
      )}

      {/* ─── DELETE CONFIRMATION DIALOG MODAL ──────────────────────────────── */}
      {companyToDelete && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-panel border border-borderDark rounded-2xl w-full max-w-sm shadow-2xl p-6 space-y-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex gap-4">
              <div className="p-3 bg-red-950/40 text-red-500 rounded-xl border border-red-900/30 self-start shrink-0">
                <AlertTriangle size={20} />
              </div>
              <div className="space-y-1.5">
                <h4 className="font-extrabold text-sm text-white">Delete Company</h4>
                <p className="text-xs text-textFaint leading-relaxed">
                  Are you sure you want to delete &ldquo;<span className="text-white font-semibold">{companyToDelete.name}</span>&rdquo;? This action is irreversible and all taxi meter configurations will be lost.
                </p>
              </div>
            </div>

            <div className="flex gap-3 justify-end text-xs">
              <button 
                onClick={() => setCompanyToDelete(null)}
                className="border border-borderDark hover:bg-borderDark/40 text-white font-bold py-2 px-4 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button 
                onClick={handleDelete}
                className="bg-red-600 hover:bg-red-700 text-white font-extrabold py-2 px-4 rounded-lg transition-colors"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};

// Svg icon helper for Sliders
const SlidersIcon = () => (
  <svg 
    xmlns="http://www.w3.org/2000/svg" 
    width="15" 
    height="15" 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    strokeWidth="2.5" 
    strokeLinecap="round" 
    strokeLinejoin="round"
  >
    <line x1="4" y1="21" x2="4" y2="14" />
    <line x1="4" y1="10" x2="4" y2="3" />
    <line x1="12" y1="21" x2="12" y2="12" />
    <line x1="12" y1="8" x2="12" y2="3" />
    <line x1="20" y1="21" x2="20" y2="16" />
    <line x1="20" y1="12" x2="20" y2="3" />
    <line x1="2" y1="14" x2="6" y2="14" />
    <line x1="10" y1="8" x2="14" y2="8" />
    <line x1="18" y1="16" x2="22" y2="16" />
  </svg>
);
