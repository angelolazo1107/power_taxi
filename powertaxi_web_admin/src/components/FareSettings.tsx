import React, { useState, useEffect } from 'react';
import { 
  subscribeToCompanies, 
  updateCompanyFareSettings 
} from '../services/firebase';
import type { Company } from '../services/firebase';
import { 
  Sliders, 
  RotateCcw, 
  Save, 
  HelpCircle, 
  Search, 
  Briefcase, 
  ArrowLeft, 
  CheckCircle, 
  AlertCircle,
  Plus,
  Minus
} from 'lucide-react';

interface FareSettingsProps {
  selectedCompanyId: string | null;
  onSelectCompany: (id: string | null) => void;
}

export const FareSettings: React.FC<FareSettingsProps> = ({ 
  selectedCompanyId, 
  onSelectCompany 
}) => {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  
  // Single company editing states
  const [editingCompany, setEditingCompany] = useState<Company | null>(null);
  const [baseFare, setBaseFare] = useState(40.0);
  const [ratePerKm, setRatePerKm] = useState(13.50);
  const [ratePerMinute, setRatePerMinute] = useState(2.00);
  const [distanceMultiplier, setDistanceMultiplier] = useState(1.00);
  
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<{ message: string; isError: boolean } | null>(null);

  // Subscribe to companies on mount
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  // Update form fields if selectedCompanyId changes
  useEffect(() => {
    if (selectedCompanyId) {
      const active = companies.find(c => c.id === selectedCompanyId);
      if (active) {
        initForm(active);
      }
    } else {
      setEditingCompany(null);
    }
  }, [selectedCompanyId, companies]);

  const initForm = (company: Company) => {
    setEditingCompany(company);
    setBaseFare(company.baseFare);
    setRatePerKm(company.ratePerKm);
    setRatePerMinute(company.ratePerMinute);
    setDistanceMultiplier(company.distanceMultiplier);
  };

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleSave = async () => {
    if (!editingCompany) return;
    
    setSaving(true);
    try {
      await updateCompanyFareSettings(editingCompany.id, {
        baseFare,
        ratePerKm,
        ratePerMinute,
        distanceMultiplier
      });
      showToast("Configuration saved successfully!");
      // Reset inline editing if applicable
      if (!selectedCompanyId) {
        setEditingCompany(null);
      }
    } catch (err: any) {
      showToast(`Save failed: ${err.message || err}`, true);
    } finally {
      setSaving(false);
    }
  };

  // Live Price Simulator Logic
  const simulatedDistance = 5.0 * distanceMultiplier;
  const simulatedTime = 8.0;
  const distanceCost = simulatedDistance * ratePerKm;
  const timeCost = simulatedTime * ratePerMinute;
  const simulatedTotal = baseFare + distanceCost + timeCost;

  // Filtered companies based on search
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

  // ─── SINGLE COMPANY FORM EDITOR STATE ──────────────────────────────────────
  if (editingCompany) {
    return (
      <div className="p-8 space-y-6 flex flex-col h-full overflow-y-auto">
        {/* Toast Notification */}
        {toast && (
          <div className={`fixed bottom-6 right-6 flex items-center gap-3 px-4 py-3 rounded-lg shadow-lg border z-50 transition-all animate-bounce ${
            toast.isError ? 'bg-red-950 border-red-800 text-red-300' : 'bg-emerald-950 border-emerald-800 text-emerald-300'
          }`}>
            {toast.isError ? <AlertCircle size={18} /> : <CheckCircle size={18} />}
            <span className="font-semibold text-sm">{toast.message}</span>
          </div>
        )}

        {/* Back and Header */}
        <div className="flex items-center gap-4">
          <button 
            onClick={() => {
              if (selectedCompanyId) {
                onSelectCompany(null);
              } else {
                setEditingCompany(null);
              }
            }}
            className="p-2 hover:bg-cardColor rounded-lg text-textFaint hover:text-white transition-colors border border-borderDark"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <h1 className="text-xl font-bold text-white">Calibrate Fare Settings</h1>
            <p className="text-xs text-textFaint">Adjusting real-time meter fare calibration parameters for &ldquo;{editingCompany.name}&rdquo;</p>
          </div>
        </div>

        {/* Split Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-6 flex-1 min-h-0">
          
          {/* Left Side: Parameters sliders */}
          <div className="lg:col-span-3 bg-panel border border-borderDark rounded-2xl p-6 flex flex-col space-y-6 overflow-y-auto">
            <div className="flex items-center gap-3">
              <Sliders className="text-accentOrange" size={20} />
              <h2 className="font-bold text-white text-base">Calibration Form</h2>
            </div>

            {/* Parameter Field: Base Fare */}
            <div className="bg-cardColor border border-borderDark rounded-xl p-4 space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm font-semibold text-white/80">Base Fare (PHP)</span>
                <span className="font-mono text-accentOrange text-sm font-bold bg-borderDark px-2 py-0.5 rounded">
                  {baseFare.toFixed(1)} PHP
                </span>
              </div>
              <div className="flex items-center gap-3">
                <button 
                  onClick={() => setBaseFare(prev => Math.max(30.0, +(prev - 5.0).toFixed(1)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Minus size={14} />
                </button>
                <input 
                  type="range" 
                  min="30" 
                  max="120" 
                  step="5"
                  value={baseFare}
                  onChange={(e) => setBaseFare(+e.target.value)}
                  className="flex-1 accent-accentOrange bg-borderDark rounded-lg appearance-none h-1.5 cursor-pointer"
                />
                <button 
                  onClick={() => setBaseFare(prev => Math.min(120.0, +(prev + 5.0).toFixed(1)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Plus size={14} />
                </button>
              </div>
            </div>

            {/* Parameter Field: Rate per KM */}
            <div className="bg-cardColor border border-borderDark rounded-xl p-4 space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm font-semibold text-white/80">Rate per Kilometer (PHP/KM)</span>
                <span className="font-mono text-accentOrange text-sm font-bold bg-borderDark px-2 py-0.5 rounded">
                  {ratePerKm.toFixed(2)} PHP
                </span>
              </div>
              <div className="flex items-center gap-3">
                <button 
                  onClick={() => setRatePerKm(prev => Math.max(5.0, +(prev - 0.50).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Minus size={14} />
                </button>
                <input 
                  type="range" 
                  min="5" 
                  max="30" 
                  step="0.5"
                  value={ratePerKm}
                  onChange={(e) => setRatePerKm(+e.target.value)}
                  className="flex-1 accent-accentOrange bg-borderDark rounded-lg appearance-none h-1.5 cursor-pointer"
                />
                <button 
                  onClick={() => setRatePerKm(prev => Math.min(30.0, +(prev + 0.50).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Plus size={14} />
                </button>
              </div>
            </div>

            {/* Parameter Field: Rate per Minute */}
            <div className="bg-cardColor border border-borderDark rounded-xl p-4 space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm font-semibold text-white/80">Rate per Minute (PHP/Min)</span>
                <span className="font-mono text-accentOrange text-sm font-bold bg-borderDark px-2 py-0.5 rounded">
                  {ratePerMinute.toFixed(2)} PHP
                </span>
              </div>
              <div className="flex items-center gap-3">
                <button 
                  onClick={() => setRatePerMinute(prev => Math.max(0.0, +(prev - 0.50).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Minus size={14} />
                </button>
                <input 
                  type="range" 
                  min="0" 
                  max="10" 
                  step="0.5"
                  value={ratePerMinute}
                  onChange={(e) => setRatePerMinute(+e.target.value)}
                  className="flex-1 accent-accentOrange bg-borderDark rounded-lg appearance-none h-1.5 cursor-pointer"
                />
                <button 
                  onClick={() => setRatePerMinute(prev => Math.min(10.0, +(prev + 0.50).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Plus size={14} />
                </button>
              </div>
            </div>

            {/* Parameter Field: Distance Multiplier */}
            <div className="bg-cardColor border border-borderDark rounded-xl p-4 space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm font-semibold text-white/80">Distance Calibration Multiplier</span>
                <span className="font-mono text-accentOrange text-sm font-bold bg-borderDark px-2 py-0.5 rounded">
                  {distanceMultiplier.toFixed(2)}x
                </span>
              </div>
              <div className="flex items-center gap-3">
                <button 
                  onClick={() => setDistanceMultiplier(prev => Math.max(0.8, +(prev - 0.05).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Minus size={14} />
                </button>
                <input 
                  type="range" 
                  min="0.8" 
                  max="1.5" 
                  step="0.05"
                  value={distanceMultiplier}
                  onChange={(e) => setDistanceMultiplier(+e.target.value)}
                  className="flex-1 accent-accentOrange bg-borderDark rounded-lg appearance-none h-1.5 cursor-pointer"
                />
                <button 
                  onClick={() => setDistanceMultiplier(prev => Math.min(1.5, +(prev + 0.05).toFixed(2)))}
                  className="p-1.5 bg-borderDark hover:bg-borderDark/80 rounded-lg text-textFaint hover:text-white transition-colors"
                >
                  <Plus size={14} />
                </button>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="pt-4 flex gap-4">
              <button 
                type="button"
                onClick={() => initForm(editingCompany)}
                disabled={saving}
                className="flex-1 flex items-center justify-center gap-2 border border-borderDark hover:bg-borderDark/30 text-white font-bold py-3 px-4 rounded-xl disabled:opacity-50 transition-colors text-sm"
              >
                <RotateCcw size={16} />
                Reset Fields
              </button>
              <button 
                type="button"
                onClick={handleSave}
                disabled={saving}
                className="flex-1 flex items-center justify-center gap-2 bg-accentOrange hover:bg-accentOrange/90 text-black font-extrabold py-3 px-4 rounded-xl disabled:opacity-50 transition-colors text-sm"
              >
                <Save size={16} />
                {saving ? "Saving..." : "Save Configuration"}
              </button>
            </div>
          </div>

          {/* Right Side: Simulator & Parameters Guide */}
          <div className="lg:col-span-2 space-y-6 flex flex-col overflow-y-auto">
            {/* Live Estimator Card */}
            <div className="bg-gradient-to-br from-accentOrange/10 via-transparent to-transparent border border-accentOrange/20 rounded-2xl p-6 space-y-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-accentOrange/15 rounded-lg text-accentOrange">
                  <HelpCircle size={18} />
                </div>
                <h3 className="font-bold text-white text-sm">Live Fare Simulator</h3>
              </div>
              <p className="text-[11px] text-textFaint">Simulating an active customer taxi ride with standard metrics:</p>
              
              <div className="space-y-2 text-xs">
                <div className="flex justify-between">
                  <span className="text-white/60">Base Starting Fare:</span>
                  <span className="font-mono text-white font-semibold">PHP {baseFare.toFixed(2)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/60">Simulated Distance (5.0 KM * {distanceMultiplier}x):</span>
                  <span className="font-mono text-white font-semibold">PHP {distanceCost.toFixed(2)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/60">Simulated Waiting Time (8.0 Min):</span>
                  <span className="font-mono text-white font-semibold">PHP {timeCost.toFixed(2)}</span>
                </div>
              </div>

              <div className="border-t border-borderDark pt-4 flex justify-between items-center">
                <span className="text-xs font-bold text-white">Estimated Fare:</span>
                <span className="font-mono text-accentOrange text-lg font-bold">
                  PHP {simulatedTotal.toFixed(2)}
                </span>
              </div>
            </div>

            {/* Guide Card */}
            <div className="bg-panel border border-borderDark rounded-2xl p-6 space-y-4 flex-1">
              <h3 className="font-bold text-white text-sm">Parameters Guide</h3>
              <div className="space-y-4 text-xs">
                <div>
                  <h4 className="font-bold text-white/80">Base Fare</h4>
                  <p className="text-textFaint mt-0.5 leading-relaxed">The static starting amount added to the meter as soon as a ride starts.</p>
                </div>
                <div>
                  <h4 className="font-bold text-white/80">Rate / KM</h4>
                  <p className="text-textFaint mt-0.5 leading-relaxed">The monetary rate charged per kilometer traveled, dynamically calculated by hardware pulses.</p>
                </div>
                <div>
                  <h4 className="font-bold text-white/80">Rate / Minute</h4>
                  <p className="text-textFaint mt-0.5 leading-relaxed">Charged incrementally during heavy traffic, red lights, or active pauses in the ride.</p>
                </div>
                <div>
                  <h4 className="font-bold text-white/80">Distance Multiplier</h4>
                  <p className="text-textFaint mt-0.5 leading-relaxed">Micro-scaling factor to adjust for sensor variance across wheel diameters or different device calibration specs.</p>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    );
  }

  // ─── DASHBOARD GRID STATE ──────────────────────────────────────────────────
  return (
    <div className="p-8 space-y-6 flex flex-col h-full overflow-y-auto">
      {/* Dashboard Top Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white">Fare Settings</h1>
          <p className="text-xs text-textFaint">Calibrate taxi meter fare calculation parameters for each registered transport company.</p>
        </div>
        
        {/* Search Bar */}
        <div className="relative">
          <Search className="absolute left-3 top-2.5 text-textFaint" size={16} />
          <input 
            type="text"
            placeholder="Search company..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 pr-4 py-2 bg-panel border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange w-64 transition-colors"
          />
        </div>
      </div>

      {/* Grid of Companies */}
      {filteredCompanies.length === 0 ? (
        <div className="flex-1 flex flex-col items-center justify-center space-y-3">
          <Briefcase className="text-textFaint/40" size={48} />
          <h3 className="text-sm font-bold text-white/80">No companies found</h3>
          <p className="text-xs text-textFaint text-center">No companies registered match your query or selection filter.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {filteredCompanies.map((c) => {
            // Detect if company settings differ from standard system defaults
            const isCustom = c.baseFare !== 40.0 || c.ratePerKm !== 13.50 || c.ratePerMinute !== 2.0 || c.distanceMultiplier !== 1.0;

            return (
              <div key={c.id} className="bg-panel border border-borderDark rounded-2xl overflow-hidden flex flex-col justify-between hover:border-borderDark/80 transition-colors">
                
                {/* Header */}
                <div className="p-5 flex justify-between items-start gap-4">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-accentOrange/10 rounded-lg text-accentOrange">
                      <Briefcase size={16} />
                    </div>
                    <div>
                      <h4 className="font-bold text-sm text-white max-w-[140px] truncate">{c.name}</h4>
                      <p className="text-[10px] text-textFaint">{c.tin ? `TIN: ${c.tin}` : 'TIN: —'}</p>
                    </div>
                  </div>

                  <span className={`px-2 py-0.5 text-[9px] font-bold rounded ${
                    isCustom 
                      ? 'bg-accentOrange/15 text-accentOrange border border-accentOrange/30' 
                      : 'bg-borderDark text-textFaint'
                  }`}>
                    {isCustom ? 'Calibrated' : 'Default'}
                  </span>
                </div>

                <div className="border-t border-borderDark px-5 py-4 space-y-2 text-xs">
                  <div className="flex justify-between">
                    <span className="text-textFaint">Base Fare:</span>
                    <span className="font-mono text-white/80 font-semibold">PHP {c.baseFare.toFixed(1)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-textFaint">Rate per KM:</span>
                    <span className="font-mono text-white/80 font-semibold">PHP {c.ratePerKm.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-textFaint">Rate per Min:</span>
                    <span className="font-mono text-white/80 font-semibold">PHP {c.ratePerMinute.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-textFaint">Multiplier:</span>
                    <span className="font-mono text-white/80 font-semibold">{c.distanceMultiplier.toFixed(2)}x</span>
                  </div>
                </div>

                <button 
                  onClick={() => initForm(c)}
                  className="w-full bg-borderDark/40 border-t border-borderDark hover:bg-borderDark/80 py-2.5 flex items-center justify-center gap-2 text-xs font-bold text-white/80 transition-colors"
                >
                  <Sliders size={13} className="text-accentOrange" />
                  Calibrate Fares
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
