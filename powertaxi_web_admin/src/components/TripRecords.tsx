import React, { useState, useEffect } from 'react';
import { subscribeToAllRides, subscribeToCompanies, subscribeToUsers } from '../services/firebase';
import type { RideRecord, Company, AppUser } from '../services/firebase';
import { 
  Receipt, 
  Search, 
  Clock, 
  TrendingUp, 
  Calendar, 
  CheckCircle2, 
  Building
} from 'lucide-react';

interface TripRecordsProps {
  selectedCompanyId: string | null;
}

export const TripRecords: React.FC<TripRecordsProps> = ({ selectedCompanyId }) => {
  const [rides, setRides] = useState<RideRecord[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Subscribe to companies
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
    });
    return () => unsubscribe();
  }, []);

  // Subscribe to users
  useEffect(() => {
    const unsubscribe = subscribeToUsers({ companyId: selectedCompanyId }, (list) => {
      setUsers(list);
    });
    return () => unsubscribe();
  }, [selectedCompanyId]);

  // Subscribe to all ride records reactively
  useEffect(() => {
    setLoading(true);
    const unsubscribe = subscribeToAllRides({ companyId: selectedCompanyId }, (list) => {
      setRides(list);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [selectedCompanyId]);

  const getDriverName = (driverId: string) => {
    const user = users.find(u => u.id === driverId || u.email === driverId);
    return user?.name || user?.email || driverId;
  };

  const getStatusDetails = (status: string) => {
    switch (status) {
      case 'completed':
        return { label: 'COMPLETED', color: 'text-blue-400 border-blue-950/40 bg-blue-950/20' };
      case 'running':
        return { label: 'RUNNING', color: 'text-emerald-400 border-emerald-950/40 bg-emerald-950/20' };
      case 'cancelled':
        return { label: 'CANCELLED', color: 'text-red-400 border-red-950/40 bg-red-950/20' };
      default:
        return { label: status.toUpperCase(), color: 'text-textFaint border-borderDark bg-[#1A1E26]' };
    }
  };

  const formatDistance = (m: number) => {
    return m >= 1000 ? `${(m / 1000).toFixed(2)} km` : `${m.toFixed(0)} m`;
  };

  const formatDateTime = (isoString: string) => {
    if (!isoString) return '—';
    try {
      const date = new Date(isoString);
      return date.toLocaleString([], { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric', 
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit'
      });
    } catch {
      return isoString;
    }
  };

  const calculateDuration = (startIso: string, endIso?: string | null) => {
    if (!startIso) return '—';
    try {
      const start = new Date(startIso);
      const end = endIso ? new Date(endIso) : new Date();
      const diffMs = end.getTime() - start.getTime();
      const diffSecs = Math.floor(diffMs / 1000);
      
      const h = Math.floor(diffSecs / 3600);
      const m = Math.floor((diffSecs % 3600) / 60);
      const s = diffSecs % 60;

      if (h > 0) return `${h}h ${m}m ${s}s`;
      if (m > 0) return `${m}m ${s}s`;
      return `${s}s`;
    } catch {
      return '—';
    }
  };

  // Filter rides list
  const filteredRides = rides.filter(r => {
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const driverName = getDriverName(r.driverId).toLowerCase();
      return (
        driverName.includes(q) ||
        r.id.toLowerCase().includes(q) ||
        r.status.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const downloadEJournal = () => {
    const completedRides = filteredRides.filter(r => r.status === 'completed');
    if (completedRides.length === 0) {
      alert("No completed rides to export.");
      return;
    }

    let content = "==========================================\n";
    content += "        BIR ELECTRONIC JOURNAL        \n";
    content += "==========================================\n\n";

    completedRides.forEach(r => {
      content += `O.R. NO.  : ${r.id.toUpperCase()}\n`;
      content += `DATE/TIME : ${formatDateTime(r.startTime)}\n`;
      content += `DRIVER    : ${getDriverName(r.driverId)}\n`;
      content += `------------------------------------------\n`;
      content += `ODOMETER  : ${formatDistance(r.distanceMeters)}\n`;
      content += `DURATION  : ${calculateDuration(r.startTime, r.endTime)}\n`;
      content += `------------------------------------------\n`;
      content += `TOTAL FARE: PHP ${r.totalFare.toFixed(2)}\n`;
      content += "==========================================\n\n";
    });

    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const dateStr = new Date().toISOString().split('T')[0];
    a.download = `EJournal_${dateStr}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accentOrange border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6 flex flex-col h-full overflow-y-auto relative">
      
      {/* Header Panel */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Receipt className="text-accentOrange" size={20} />
            Historic Trip Records
          </h1>
          <p className="text-xs text-textFaint">
            View, audit, and inspect all historical rides and active transactions completed by your drivers.
          </p>
        </div>

        {/* Global Company Scope Tag */}
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Scope Filter: {companies.find(c => c.id === selectedCompanyId)?.name || 'Filtered'}
          </div>
        )}
      </div>

      {/* Stats Cards Banner */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Card 1: Total Trips */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4">
          <div className="p-3 bg-white/5 text-textFaint rounded-lg">
            <Receipt size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-textFaint uppercase block tracking-wider">Total Recorded Rides</span>
            <span className="text-2xl font-black text-white">{rides.length}</span>
          </div>
        </div>

        {/* Card 2: Completed Trips */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4">
          <div className="p-3 bg-blue-950/20 text-blue-400 rounded-lg">
            <CheckCircle2 size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-blue-500/80 uppercase block tracking-wider">Completed Rides</span>
            <span className="text-2xl font-black text-blue-400">
              {rides.filter(r => r.status === 'completed').length}
            </span>
          </div>
        </div>

        {/* Card 3: Active Trips */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4">
          <div className="p-3 bg-emerald-950/20 text-emerald-400 rounded-lg">
            <Clock size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-emerald-500/80 uppercase block tracking-wider">Currently Running</span>
            <span className="text-2xl font-black text-emerald-400">
              {rides.filter(r => r.status === 'running').length}
            </span>
          </div>
        </div>
      </div>

      {/* Toolbar Search */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md w-full">
          <Search className="absolute left-3 top-2.5 text-textFaint" size={15} />
          <input 
            type="text"
            placeholder="Search by driver ID, trip ID, or status..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-[#1A1E26] border border-borderDark rounded-lg text-xs text-white placeholder-textFaint focus:outline-none focus:border-accentOrange transition-colors"
          />
        </div>
        
        <button
          onClick={downloadEJournal}
          className="flex items-center gap-2 px-4 py-2 bg-[#1A1E26] hover:bg-[#232833] border border-borderDark rounded-lg text-xs font-bold text-white transition-colors"
        >
          <TrendingUp size={15} className="text-accentOrange" />
          Export E-Journal (TXT)
        </button>
      </div>

      {/* Main Table Directory */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        <div className="flex-1 overflow-y-auto">
          {filteredRides.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <Receipt className="text-textFaint/20 animate-pulse" size={56} />
              <h4 className="text-sm font-bold text-white/80">No trip records found</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">There are no ride receipts logged under this company or search query.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-[10px] uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-4">Trip Document ID</th>
                  <th className="px-6 py-4">Driver Profile</th>
                  <th className="px-6 py-4">Date / Time (Start)</th>
                  <th className="px-6 py-4">Duration</th>
                  <th className="px-6 py-4 text-right">Odometer</th>
                  <th className="px-6 py-4 text-right">Fare Total</th>
                  <th className="px-6 py-4 text-center w-28">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-xs font-medium">
                {filteredRides.map(r => {
                  const status = getStatusDetails(r.status);
                  return (
                    <tr key={r.id} className="hover:bg-cardColor/30 transition-colors">
                      {/* Document ID */}
                      <td className="px-6 py-4 font-mono text-white/70">
                        {r.id}
                      </td>

                      {/* Driver ID */}
                      <td className="px-6 py-4 font-mono text-white">
                        {getDriverName(r.driverId)}
                      </td>

                      {/* Date / Time */}
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2 text-white/95">
                          <Calendar size={13} className="text-textFaint" />
                          {formatDateTime(r.startTime)}
                        </div>
                      </td>

                      {/* Duration */}
                      <td className="px-6 py-4 text-white/95">
                        <div className="flex items-center gap-1.5">
                          <Clock size={13} className="text-textFaint" />
                          {calculateDuration(r.startTime, r.endTime)}
                        </div>
                      </td>

                      {/* Distance */}
                      <td className="px-6 py-4 text-right font-mono text-white/90">
                        {formatDistance(r.distanceMeters)}
                      </td>

                      {/* Total Fare */}
                      <td className="px-6 py-4 text-right">
                        <div className="flex flex-col items-end">
                          <span className="text-white font-mono text-[13px] font-bold">₱{r.totalFare.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                          <span className="text-[8px] text-textFaint flex items-center gap-0.5 uppercase tracking-wider">
                            <TrendingUp size={9} className="text-accentOrange" /> Gross
                          </span>
                        </div>
                      </td>

                      {/* Status */}
                      <td className="px-6 py-4 w-28 text-center">
                        <span className={`px-2.5 py-0.5 border text-[9px] font-extrabold rounded-md ${status.color}`}>
                          {status.label}
                        </span>
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
