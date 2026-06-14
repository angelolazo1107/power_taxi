import React, { useState, useEffect } from 'react';
import { subscribeToDevices, updateDevice } from '../services/firebase';
import type { Device } from '../services/firebase';
import { 
  Wrench, 
  Search, 
  AlertTriangle, 
  CheckCircle, 
  AlertCircle, 
  Building,
  RefreshCw,
  Tablet
} from 'lucide-react';

interface MaintenanceProps {
  selectedCompanyId: string | null;
}

export const Maintenance: React.FC<MaintenanceProps> = ({ selectedCompanyId }) => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [toast, setToast] = useState<{ message: string; isError: boolean } | null>(null);

  useEffect(() => {
    setLoading(true);
    const unsubscribe = subscribeToDevices({ companyId: selectedCompanyId }, (list) => {
      // Filter only devices needing maintenance
      setDevices(list.filter(d => d.needsMaintenance));
      setLoading(false);
    });
    return () => unsubscribe();
  }, [selectedCompanyId]);

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleResetOil = async (device: Device) => {
    try {
      const currentOdo = device.odometer || 0;
      const lastTire = device.lastTireChangeOdometer || 0;
      
      let needsMaint = false;
      const reasons: string[] = [];
      
      // Since oil is reset to current, diff is 0 (not >= 5000)
      if (currentOdo - lastTire >= 10000) {
        needsMaint = true;
        reasons.push("Tire Rotation/Change Required (Overdue)");
      }

      await updateDevice({
        ...device,
        lastOilChangeOdometer: currentOdo,
        needsMaintenance: needsMaint,
        maintenanceReason: reasons.join(" & ")
      });
      showToast(`Oil change logged for ${device.plateNo || device.serialNo}. Odometer reset to ${currentOdo.toLocaleString()} KM.`);
    } catch (err: any) {
      showToast(`Failed to reset oil threshold: ${err.message || err}`, true);
    }
  };

  const handleResetTires = async (device: Device) => {
    try {
      const currentOdo = device.odometer || 0;
      const lastOil = device.lastOilChangeOdometer || 0;
      
      let needsMaint = false;
      const reasons: string[] = [];
      
      if (currentOdo - lastOil >= 5000) {
        needsMaint = true;
        reasons.push("Oil Change Required (Overdue)");
      }
      // Since tires are reset to current, diff is 0 (not >= 10000)

      await updateDevice({
        ...device,
        lastTireChangeOdometer: currentOdo,
        needsMaintenance: needsMaint,
        maintenanceReason: reasons.join(" & ")
      });
      showToast(`Tire change/rotation logged for ${device.plateNo || device.serialNo}. Odometer reset to ${currentOdo.toLocaleString()} KM.`);
    } catch (err: any) {
      showToast(`Failed to reset tire threshold: ${err.message || err}`, true);
    }
  };

  const filteredDevices = devices.filter(d => 
    d.serialNo.toLowerCase().includes(searchQuery.toLowerCase()) ||
    d.plateNo.toLowerCase().includes(searchQuery.toLowerCase()) ||
    d.company.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (d.currentDriver || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Statistics
  const oilOverdueCount = devices.filter(d => {
    const odo = d.odometer || 0;
    const lastOil = d.lastOilChangeOdometer || 0;
    return (odo - lastOil) >= 5000;
  }).length;

  const tiresOverdueCount = devices.filter(d => {
    const odo = d.odometer || 0;
    const lastTire = d.lastTireChangeOdometer || 0;
    return (odo - lastTire) >= 10000;
  }).length;

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
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Wrench className="text-accentOrange" size={22} />
            Vehicle Maintenance Dashboard
          </h1>
          <p className="text-xs text-textFaint">
            View, diagnose, and reset service logs for vehicles requiring oil changes or tire replacement.
          </p>
        </div>
      </div>

      {/* Summary Row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Total Needing Service */}
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex items-center gap-3">
          <div className="p-2.5 bg-red-500/10 rounded-lg text-red-500 border border-red-500/20">
            <AlertTriangle size={18} />
          </div>
          <div>
            <span className="text-lg font-black text-white">{devices.length}</span>
            <span className="text-[10px] font-semibold text-textFaint ml-2">Total Service Requests</span>
          </div>
        </div>

        {/* Oil Changes Overdue */}
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex items-center gap-3">
          <div className="p-2.5 bg-amber-500/10 rounded-lg text-amber-500 border border-amber-500/20">
            <Wrench size={18} />
          </div>
          <div>
            <span className="text-lg font-black text-white">{oilOverdueCount}</span>
            <span className="text-[10px] font-semibold text-textFaint ml-2">Oil Service Pending</span>
          </div>
        </div>

        {/* Tire Changes Overdue */}
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex items-center gap-3">
          <div className="p-2.5 bg-amber-500/10 rounded-lg text-amber-500 border border-amber-500/20">
            <RefreshCw size={18} />
          </div>
          <div>
            <span className="text-lg font-black text-white">{tiresOverdueCount}</span>
            <span className="text-[10px] font-semibold text-textFaint ml-2">Tire Service Pending</span>
          </div>
        </div>
      </div>

      {/* Toolbar & Search */}
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Filter Company Active
          </div>
        )}
        <div className="relative flex-1 max-w-md md:ml-auto w-full">
          <Search className="absolute left-3 top-2.5 text-textFaint" size={15} />
          <input 
            type="text"
            placeholder="Search by plate, body, company..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-[#1A1E26] border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange transition-colors"
          />
        </div>
      </div>

      {/* Main Directory Table */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        <div className="flex-1 overflow-y-auto">
          {filteredDevices.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <CheckCircle className="text-emerald-500/20 animate-pulse" size={56} />
              <h4 className="text-sm font-bold text-white/80">All Vehicles Clear</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">No taxi meters currently require odometer-based maintenance.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-[10px] uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-3.5">Plate / Body</th>
                  <th className="px-6 py-3.5">Company</th>
                  <th className="px-6 py-3.5">Current Odometer</th>
                  <th className="px-6 py-3.5">Oil Maintenance</th>
                  <th className="px-6 py-3.5">Tire Maintenance</th>
                  <th className="px-6 py-3.5 text-center w-52">Calibration Reset</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-xs font-medium">
                {filteredDevices.map((d) => {
                  const odo = d.odometer || 0;
                  const lastOil = d.lastOilChangeOdometer || 0;
                  const lastTire = d.lastTireChangeOdometer || 0;
                  
                  const oilDiff = odo - lastOil;
                  const tireDiff = odo - lastTire;
                  
                  const oilRemaining = 5000 - oilDiff;
                  const tireRemaining = 10000 - tireDiff;
                  
                  const oilOverdue = oilRemaining <= 0;
                  const tireOverdue = tireRemaining <= 0;

                  return (
                    <tr key={d.serialNo} className="hover:bg-cardColor/30 transition-colors">
                      {/* Plate Column */}
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="p-2 bg-borderDark rounded-lg text-white/80">
                            <Tablet size={14} />
                          </div>
                          <div className="flex flex-col">
                            <span className="font-mono font-bold text-white tracking-wider">{d.plateNo}</span>
                            <span className="text-[10px] text-textFaint">Body: #{d.bodyNo} • {d.serialNo}</span>
                          </div>
                        </div>
                      </td>

                      {/* Company */}
                      <td className="px-6 py-4">
                        <span className="text-white/80 truncate max-w-[140px] block" title={d.company}>{d.company}</span>
                      </td>

                      {/* Current Odometer */}
                      <td className="px-6 py-4 font-mono font-bold text-white text-[13px]">
                        {odo.toLocaleString(undefined, { minimumFractionDigits: 1, maximumFractionDigits: 1 })} KM
                      </td>

                      {/* Oil Service */}
                      <td className="px-6 py-4">
                        <div className="flex flex-col gap-1">
                          <span className={oilOverdue ? 'text-red-500 font-extrabold flex items-center gap-1' : 'text-white/80'}>
                            {oilOverdue ? '⚠️ Overdue' : 'Good'}
                          </span>
                          <span className="text-[10px] text-textFaint">
                            {oilOverdue 
                              ? `${Math.abs(Math.round(oilRemaining)).toLocaleString()} KM Overdue`
                              : `${Math.round(oilRemaining).toLocaleString()} KM remaining`
                            }
                          </span>
                        </div>
                      </td>

                      {/* Tire Service */}
                      <td className="px-6 py-4">
                        <div className="flex flex-col gap-1">
                          <span className={tireOverdue ? 'text-red-500 font-extrabold flex items-center gap-1' : 'text-white/80'}>
                            {tireOverdue ? '⚠️ Overdue' : 'Good'}
                          </span>
                          <span className="text-[10px] text-textFaint">
                            {tireOverdue 
                              ? `${Math.abs(Math.round(tireRemaining)).toLocaleString()} KM Overdue`
                              : `${Math.round(tireRemaining).toLocaleString()} KM remaining`
                            }
                          </span>
                        </div>
                      </td>

                      {/* Action buttons */}
                      <td className="px-6 py-4 w-52">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => handleResetOil(d)}
                            disabled={!oilOverdue}
                            className={`flex-1 py-1.5 px-2.5 rounded-lg text-[10px] font-bold transition-all ${
                              oilOverdue 
                                ? 'bg-amber-500 hover:bg-amber-600 text-black shadow shadow-amber-500/10 cursor-pointer' 
                                : 'bg-[#1A1E26] text-textFaint border border-borderDark opacity-50 cursor-not-allowed'
                            }`}
                            title="Log new oil change"
                          >
                            Reset Oil
                          </button>
                          <button
                            onClick={() => handleResetTires(d)}
                            disabled={!tireOverdue}
                            className={`flex-1 py-1.5 px-2.5 rounded-lg text-[10px] font-bold transition-all ${
                              tireOverdue 
                                ? 'bg-amber-500 hover:bg-amber-600 text-black shadow shadow-amber-500/10 cursor-pointer' 
                                : 'bg-[#1A1E26] text-textFaint border border-borderDark opacity-50 cursor-not-allowed'
                            }`}
                            title="Log tire replacement"
                          >
                            Reset Tires
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

    </div>
  );
};
