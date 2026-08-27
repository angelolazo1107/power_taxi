import React, { useState, useEffect } from 'react';
import { subscribeToDevices, subscribeToCompanies } from '../services/firebase';
import type { Device, Company } from '../services/firebase';
import { 
  Radio, 
  Search, 
  Clock, 
  TrendingUp, 
  Compass, 
  WifiOff, 
  Activity, 
  CheckCircle2, 
  Building,
  Wrench
} from 'lucide-react';

interface DispatchMonitorProps {
  selectedCompanyId: string | null;
  selectedCompanyName: string | null;
}

type StatusFilter = 'all' | 'online' | 'onRide' | 'onBreak' | 'offline' | 'maintenance';

export const DispatchMonitor: React.FC<DispatchMonitorProps> = ({ 
  selectedCompanyId, 
  selectedCompanyName 
}) => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [now, setNow] = useState(new Date());

  // Heartbeat updater to re-evaluate 'disconnected' status every 10 seconds
  useEffect(() => {
    const timer = setInterval(() => {
      setNow(new Date());
    }, 10000);
    return () => clearInterval(timer);
  }, []);

  // Subscribe to companies
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
    });
    return () => unsubscribe();
  }, []);

  // Subscribe to devices reactively based on global company select
  useEffect(() => {
    setLoading(true);
    const unsubscribe = subscribeToDevices(
      { companyId: selectedCompanyId, companyName: selectedCompanyName }, 
      (list) => {
        setDevices(list);
        setLoading(false);
      }
    );
    return () => unsubscribe();
  }, [selectedCompanyId, selectedCompanyName]);

  const resolveStatus = (d: Device) => {
    if (d.lastSeen) {
      const lastSeenDate = d.lastSeen.toDate ? d.lastSeen.toDate() : new Date(d.lastSeen);
      const diffMins = (now.getTime() - lastSeenDate.getTime()) / 60000;
      if (diffMins > 2) {
        return 'disconnected';
      }
    }
    return d.status; // 'running' | 'idle' | 'offline'
  };

  const getStatusDetails = (status: string) => {
    switch (status) {
      case 'running':
        return { label: 'HIRED', color: 'text-red-500 border-red-500/20 bg-red-500/10', dot: 'bg-red-500' };
      case 'idle':
        return { label: 'VACANT', color: 'text-emerald-500 border-emerald-500/20 bg-emerald-500/10', dot: 'bg-emerald-500' };
      case 'break':
        return { label: 'ON BREAK', color: 'text-amber-500 border-amber-500/20 bg-amber-500/10', dot: 'bg-amber-500' };
      case 'disconnected':
        return { label: 'DISCONNECTED', color: 'text-slate-50 border-neutral-800 bg-neutral-950', dot: 'bg-black border border-neutral-600' };
      default:
        return { label: 'OFFLINE', color: 'text-slate-50 border-neutral-800 bg-neutral-950', dot: 'bg-black border border-neutral-600' };
    }
  };

  const formatDuration = (secs: number) => {
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m`;
    return `${secs}s`;
  };

  const formatDistance = (m: number) => {
    return m >= 1000 ? `${(m / 1000).toFixed(2)} km` : `${m.toFixed(0)} m`;
  };

  const formatLastSeen = (lastSeen: any) => {
    if (!lastSeen) return '—';
    const date = lastSeen.toDate ? lastSeen.toDate() : new Date(lastSeen);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  };

  // Filter devices
  const filteredDevices = devices.filter(d => {
    const resolved = resolveStatus(d);
    
    // Status Filter
    if (filter === 'online' && resolved !== 'idle') return false;
    if (filter === 'onRide' && resolved !== 'running') return false;
    if (filter === 'onBreak' && resolved !== 'break') return false;
    if (filter === 'offline' && resolved !== 'offline' && resolved !== 'disconnected') return false;
    if (filter === 'maintenance' && !d.needsMaintenance) return false;

    // Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        d.plateNo.toLowerCase().includes(q) ||
        d.bodyNo.toLowerCase().includes(q) ||
        (d.currentDriver || '').toLowerCase().includes(q) ||
        d.serialNo.toLowerCase().includes(q)
      );
    }
    return true;
  });

  // Calculate metrics counts for stats cards
  const cntTotal = devices.length;
  const cntOnline = devices.filter(d => resolveStatus(d) === 'idle').length;
  const cntOnRide = devices.filter(d => resolveStatus(d) === 'running').length;
  const cntOnBreak = devices.filter(d => resolveStatus(d) === 'break').length;
  const cntOffline = devices.filter(d => {
    const s = resolveStatus(d);
    return s === 'offline' || s === 'disconnected';
  }).length;
  const cntMaintenance = devices.filter(d => d.needsMaintenance).length;

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
            <Radio className="text-accentOrange animate-pulse" size={20} />
            Real-Time Dispatch Monitoring
          </h1>
          <p className="text-xs text-textFaint">
            Live status, passenger activity, and today's operational indicators across your fleet.
          </p>
        </div>

        {/* Global Company Scope Indicator */}
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Scope Filter: {companies.find(c => c.id === selectedCompanyId)?.name || 'Filtered'}
          </div>
        )}
      </div>

      {/* Grid Stats cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        {/* Card 1: TOTAL */}
        <div 
          onClick={() => setFilter('all')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'all' 
              ? 'border-accentOrange bg-accentOrange/5 shadow-md shadow-accentOrange/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-white/5 text-textFaint rounded-lg">
            <Compass size={22} />
          </div>
          <div>
            <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Total Terminals</span>
            <span className="text-3xl font-black text-white">{cntTotal}</span>
          </div>
        </div>

        {/* Card 2: HIRED */}
        <div 
          onClick={() => setFilter('onRide')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'onRide' 
              ? 'border-red-500 bg-red-500/5 shadow-md shadow-red-500/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-red-500/10 text-red-500 rounded-lg">
            <Activity size={22} />
          </div>
          <div>
            <span className="text-xs font-bold text-red-500/80 uppercase block tracking-wider">Hired</span>
            <span className="text-3xl font-black text-red-500">{cntOnRide}</span>
          </div>
        </div>

        {/* Card 3: VACANT */}
        <div 
          onClick={() => setFilter('online')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'online' 
              ? 'border-emerald-500 bg-emerald-500/5 shadow-md shadow-emerald-500/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-emerald-500/10 text-emerald-500 rounded-lg">
            <CheckCircle2 size={22} />
          </div>
          <div>
            <span className="text-xs font-bold text-emerald-500/80 uppercase block tracking-wider">Vacant</span>
            <span className="text-3xl font-black text-emerald-500">{cntOnline}</span>
          </div>
        </div>
        
        {/* Card: ON BREAK */}
        <div 
          onClick={() => setFilter('onBreak')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'onBreak' 
              ? 'border-amber-500 bg-amber-500/5 shadow-md shadow-amber-500/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-amber-500/10 text-amber-500 rounded-lg">
            <Clock size={22} />
          </div>
          <div>
            <span className="text-xs font-bold text-amber-500/80 uppercase block tracking-wider">On Break</span>
            <span className="text-3xl font-black text-amber-500">{cntOnBreak}</span>
          </div>
        </div>

        {/* Card 5: MAINTENANCE */}
        <div 
          onClick={() => setFilter('maintenance')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'maintenance' 
              ? 'border-amber-500 bg-amber-500/5 shadow-md shadow-amber-500/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-amber-500/10 text-amber-500 rounded-lg">
            <Wrench size={22} />
          </div>
          <div>
            <span className="text-xs font-bold text-amber-500/80 uppercase block tracking-wider">Maintenance</span>
            <span className="text-3xl font-black text-amber-500">{cntMaintenance}</span>
          </div>
        </div>

        {/* Card 6: OFFLINE */}
        <div 
          onClick={() => setFilter('offline')}
          className={`bg-panel border rounded-xl p-5 flex items-center gap-4 cursor-pointer transition-all ${
            filter === 'offline' 
              ? 'border-neutral-900 bg-neutral-950/5 shadow-md shadow-accentOrange/5' 
              : 'border-borderDark hover:border-textFaint/45'
          }`}
        >
          <div className="p-3 bg-black rounded-lg border border-neutral-800 flex items-center justify-center">
            <WifiOff size={22} style={{ color: '#ffffff' }} />
          </div>
          <div>
            <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Offline</span>
            <span className="text-3xl font-black text-white">{cntOffline}</span>
          </div>
        </div>
      </div>

      {/* Toolbar Filters + Search */}
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        {/* Tab filters */}
        <div className="flex gap-2 p-1.5 bg-[#1A1E26] border border-borderDark rounded-xl self-start">
          <button 
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'all' ? 'bg-borderDark text-white' : 'text-textFaint hover:text-white'
            }`}
          >
            All <span className="ml-1 text-xs opacity-60">({cntTotal})</span>
          </button>
          <button 
            onClick={() => setFilter('onRide')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'onRide' ? 'bg-red-500/10 text-red-500 border border-red-500/20' : 'text-textFaint hover:text-red-500'
            }`}
          >
            Hired <span className="ml-1 text-xs opacity-60">({cntOnRide})</span>
          </button>
          <button 
            onClick={() => setFilter('online')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'online' ? 'bg-emerald-500/10 text-emerald-500 border border-emerald-500/20' : 'text-textFaint hover:text-emerald-500'
            }`}
          >
            Vacant <span className="ml-1 text-xs opacity-60">({cntOnline})</span>
          </button>
          <button 
            onClick={() => setFilter('onBreak')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'onBreak' ? 'bg-amber-500/10 text-amber-500 border border-amber-500/20' : 'text-textFaint hover:text-amber-500'
            }`}
          >
            On Break <span className="ml-1 text-xs opacity-60">({cntOnBreak})</span>
          </button>
          <button 
            onClick={() => setFilter('maintenance')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'maintenance' ? 'bg-amber-500/10 text-amber-500 border border-amber-500/20' : 'text-textFaint hover:text-amber-500'
            }`}
          >
            Maintenance <span className="ml-1 text-xs opacity-60">({cntMaintenance})</span>
          </button>
          <button 
            onClick={() => setFilter('offline')}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              filter === 'offline' ? 'bg-black text-slate-50 border border-neutral-900' : 'text-textFaint hover:text-white hover:bg-borderDark/20'
            }`}
          >
            Offline <span className="ml-1 text-xs opacity-60">({cntOffline})</span>
          </button>
        </div>

        {/* Search */}
        <div className="relative flex-1 max-w-md md:ml-auto w-full">
          <Search className="absolute left-3.5 top-3 text-textFaint" size={18} />
          <input 
            type="text"
            placeholder="Search plate, body no, driver..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-11 pr-4 py-2.5 bg-[#1A1E26] border border-borderDark rounded-lg text-sm text-white placeholder-textFaint focus:outline-none focus:border-accentOrange transition-colors"
          />
        </div>
      </div>

      {/* Live Monitor Table */}
      <div className="bg-panel border border-borderDark rounded-2xl flex flex-col min-h-0 flex-1 overflow-hidden">
        <div className="flex-1 overflow-y-auto">
          {filteredDevices.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center space-y-3 py-16">
              <Compass className="text-textFaint/20 animate-spin duration-1000" size={56} />
              <h4 className="text-sm font-bold text-white/80">No active dispatch terminals found</h4>
              <p className="text-xs text-textFaint text-center max-w-xs">There are no taxi meters fitting this status or text filter.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead className="bg-[#1A1E26]/50 border-b border-borderDark text-xs uppercase font-bold text-textFaint tracking-wider shrink-0 sticky top-0 z-10">
                <tr>
                  <th className="px-6 py-4">Terminal / Plate</th>
                  <th className="px-6 py-4">Current Status</th>
                  <th className="px-6 py-4">Active Driver</th>
                  <th className="px-6 py-4 text-right">Daily Sales</th>
                  <th className="px-6 py-4 text-right">Daily Distance</th>
                  <th className="px-6 py-4 text-right">Wait Duration</th>
                  <th className="px-6 py-4 text-right">Last Seen</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-sm font-medium">
                {filteredDevices.map(d => {
                  const resolvedStatus = resolveStatus(d);
                  const status = getStatusDetails(resolvedStatus);
                  return (
                    <tr key={d.serialNo} className="hover:bg-cardColor/30 transition-colors">
                      {/* Terminal Name */}
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className={`w-1.5 h-7 rounded ${status.dot}`}></div>
                          <div className="flex flex-col">
                            <span className="text-white font-extrabold text-sm tracking-wide font-mono">{d.plateNo}</span>
                            <span className="text-xs text-textFaint">Body #{d.bodyNo} • {d.serialNo}</span>
                          </div>
                        </div>
                      </td>

                      {/* Status badge */}
                      <td className="px-6 py-4">
                        <span className={`px-2 py-1 border text-[10px] font-extrabold rounded-md ${status.color}`}>
                          {status.label}
                        </span>
                      </td>

                      {/* Active Driver */}
                      <td className="px-6 py-4">
                        <span className={`text-sm ${d.currentDriver ? 'text-white' : 'text-textFaint/60 font-normal'}`}>
                          {d.currentDriver || '—'}
                        </span>
                      </td>

                      {/* Sales */}
                      <td className="px-6 py-4 text-right">
                        <div className="flex flex-col items-end">
                          <span className="text-white font-mono text-sm font-bold">₱{d.dailySales.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                          <span className="text-[10px] text-textFaint flex items-center gap-0.5 uppercase tracking-wider">
                            <TrendingUp size={11} className="text-accentOrange" /> Today
                          </span>
                        </div>
                      </td>

                      {/* Distance */}
                      <td className="px-6 py-4 text-right font-mono text-white/90">
                        {formatDistance(d.dailyDistanceMeters)}
                      </td>

                      {/* Wait Time */}
                      <td className="px-6 py-4 text-right font-mono text-white/90">
                        <div className="flex items-center gap-1.5 justify-end">
                          <Clock size={14} className="text-textFaint" />
                          {formatDuration(d.dailyWaitingSeconds)}
                        </div>
                      </td>

                      {/* Last seen time */}
                      <td className="px-6 py-4 text-right font-mono text-white/80">
                        {formatLastSeen(d.lastSeen)}
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
