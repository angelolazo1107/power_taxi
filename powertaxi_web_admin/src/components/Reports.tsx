import React, { useState, useEffect } from 'react';
import { subscribeToAllRides, subscribeToDevices, subscribeToCompanies, subscribeToUsers } from '../services/firebase';
import type { RideRecord, Device, Company, AppUser } from '../services/firebase';
import { 
  BarChart3, 
  DollarSign, 
  Milestone, 
  Percent, 
  Building, 
  TrendingUp, 
  Activity, 
  Award
} from 'lucide-react';

interface ReportsProps {
  selectedCompanyId: string | null;
}

export const Reports: React.FC<ReportsProps> = ({ selectedCompanyId }) => {
  const [rides, setRides] = useState<RideRecord[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [loading, setLoading] = useState(true);

  // Subscribe to companies, devices, rides, and users
  useEffect(() => {
    setLoading(true);
    const unsubCompanies = subscribeToCompanies((companyList) => {
      setCompanies(companyList);
    });

    const unsubDevices = subscribeToDevices({ companyId: selectedCompanyId }, (deviceList) => {
      setDevices(deviceList);
    });

    const unsubRides = subscribeToAllRides({ companyId: selectedCompanyId }, (rideList) => {
      setRides(rideList);
      setLoading(false);
    });

    const unsubUsers = subscribeToUsers({ companyId: selectedCompanyId }, (userList) => {
      setUsers(userList);
    });

    return () => {
      unsubCompanies();
      unsubDevices();
      unsubRides();
      unsubUsers();
    };
  }, [selectedCompanyId]);

  const getDriverName = (driverId: string) => {
    const user = users.find(u => u.id === driverId || u.email === driverId);
    return user?.name || user?.email || driverId;
  };

  // Calculations
  const completedRides = rides.filter(r => r.status === 'completed');
  const runningRides = rides.filter(r => r.status === 'running');
  const cancelledRides = rides.filter(r => r.status === 'cancelled');

  const grossRevenue = completedRides.reduce((acc, r) => acc + r.totalFare, 0) + 
                       runningRides.reduce((acc, r) => acc + r.totalFare, 0);

  const totalRidesCount = rides.length;
  const averageFare = totalRidesCount > 0 ? grossRevenue / totalRidesCount : 0.0;
  
  const totalDistanceMeters = rides.reduce((acc, r) => acc + r.distanceMeters, 0);
  const totalDistanceKm = totalDistanceMeters / 1000;

  // Completed ratio
  const completionRatio = totalRidesCount > 0 
    ? (completedRides.length / totalRidesCount) * 100 
    : 0;

  // Active Utilization rate
  const totalMeters = devices.length;
  const activeMeters = devices.filter(d => d.status === 'running').length;
  const utilizationRate = totalMeters > 0 
    ? (activeMeters / totalMeters) * 100 
    : 0;

  // Get revenue per company
  const companyRevenueData = companies.map(c => {
    const companyRides = rides.filter(r => r.companyId === c.id);
    const companyCompleted = companyRides.filter(r => r.status === 'completed' || r.status === 'running');
    const totalRev = companyCompleted.reduce((acc, r) => acc + r.totalFare, 0);
    return {
      name: c.name,
      revenue: totalRev,
      ridesCount: companyRides.length
    };
  }).sort((a, b) => b.revenue - a.revenue);

  // Top performing drivers / trips
  const topTrips = [...rides]
    .sort((a, b) => b.totalFare - a.totalFare)
    .slice(0, 3);

  // Calculate highest revenue amount to calibrate visual charts properly
  const maxCompanyRev = Math.max(...companyRevenueData.map(d => d.revenue), 1);

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
            <BarChart3 className="text-accentOrange" size={20} />
            Reports & Fleet Analytics
          </h1>
          <p className="text-xs text-textFaint">
            Aggregated revenue performance, device utilization ratios, and operational trip spreads.
          </p>
        </div>

        {/* Global Company Scope */}
        {selectedCompanyId && (
          <div className="px-3 py-2 bg-accentOrange/5 border border-accentOrange/20 text-accentOrange rounded-lg text-[10px] font-semibold flex items-center gap-2 self-start md:self-auto">
            <Building size={12} />
            Scope Filter: {companies.find(c => c.id === selectedCompanyId)?.name || 'Filtered'}
          </div>
        )}
      </div>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        
        {/* KPI 1: Gross Revenue */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
          <div className="p-3 bg-accentOrange/10 text-accentOrange rounded-lg">
            <DollarSign size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-textFaint uppercase block tracking-wider">Gross Fleet Revenue</span>
            <span className="text-2xl font-black text-white font-mono">
              ₱{grossRevenue.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </span>
          </div>
          <div className="absolute top-0 right-0 w-24 h-24 bg-accentOrange/5 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
        </div>

        {/* KPI 2: Average Ticket */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
          <div className="p-3 bg-amber-950/20 text-amber-400 rounded-lg">
            <TrendingUp size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-textFaint uppercase block tracking-wider">Average Ticket Fare</span>
            <span className="text-2xl font-black text-white font-mono">
              ₱{averageFare.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </span>
          </div>
          <div className="absolute top-0 right-0 w-24 h-24 bg-amber-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
        </div>

        {/* KPI 3: Total Distance */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
          <div className="p-3 bg-blue-950/20 text-blue-400 rounded-lg">
            <Milestone size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-textFaint uppercase block tracking-wider">Distance Traverse</span>
            <span className="text-2xl font-black text-white font-mono">
              {totalDistanceKm.toFixed(2)} km
            </span>
          </div>
          <div className="absolute top-0 right-0 w-24 h-24 bg-blue-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
        </div>

        {/* KPI 4: Completion Rate */}
        <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
          <div className="p-3 bg-emerald-950/20 text-emerald-400 rounded-lg">
            <Percent size={20} />
          </div>
          <div>
            <span className="text-[10px] font-bold text-textFaint uppercase block tracking-wider">Completion Success</span>
            <span className="text-2xl font-black text-white font-mono">
              {completionRatio.toFixed(1)}%
            </span>
          </div>
          <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
        </div>

      </div>

      {/* Main Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Left Card: Company Revenue Breakdown */}
        <div className="bg-panel border border-borderDark rounded-2xl p-6 space-y-6 lg:col-span-2">
          <div>
            <h3 className="font-extrabold text-sm text-white">Revenue Performance comparison</h3>
            <p className="text-[10px] text-textFaint">Total transaction value aggregated by registered fleet operators.</p>
          </div>

          <div className="space-y-4">
            {companyRevenueData.length === 0 ? (
              <p className="text-xs text-textFaint">No company revenue data available to render charts.</p>
            ) : (
              companyRevenueData.map(c => {
                const ratio = (c.revenue / maxCompanyRev) * 100;
                return (
                  <div key={c.name} className="space-y-2">
                    <div className="flex items-center justify-between text-xs font-semibold">
                      <span className="text-white/80">{c.name}</span>
                      <div className="flex gap-2 items-center">
                        <span className="text-textFaint text-[10px]">{c.ridesCount} rides</span>
                        <span className="text-white font-mono font-bold">
                          ₱{c.revenue.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </span>
                      </div>
                    </div>
                    {/* Visual Progress bar */}
                    <div className="w-full h-3 bg-borderDark rounded-full overflow-hidden">
                      <div 
                        className="h-full bg-gradient-to-r from-accentOrange/80 to-accentOrange rounded-full transition-all duration-500"
                        style={{ width: `${Math.max(ratio, 4)}%` }}
                      ></div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Card: Outcomes & Utilization Gauges */}
        <div className="bg-panel border border-borderDark rounded-2xl p-6 space-y-6 flex flex-col justify-between">
          <div className="space-y-5">
            <div>
              <h3 className="font-extrabold text-sm text-white">Fleet Utilization & Outcomes</h3>
              <p className="text-[10px] text-textFaint">Live hardware active percentages and historic outcomes.</p>
            </div>

            {/* Live Utilization Meter Ring */}
            <div className="flex items-center gap-4 p-4 bg-cardColor/30 border border-borderDark rounded-xl">
              <div className="relative w-16 h-16 shrink-0 flex items-center justify-center">
                {/* SVG Radial Gauge */}
                <svg className="w-full h-full transform -rotate-90">
                  <circle cx="32" cy="32" r="28" className="stroke-borderDark fill-none stroke-[6]" />
                  <circle 
                    cx="32" 
                    cy="32" 
                    r="28" 
                    className="stroke-accentOrange fill-none stroke-[6] transition-all duration-1000" 
                    strokeDasharray={2 * Math.PI * 28}
                    strokeDashoffset={2 * Math.PI * 28 * (1 - utilizationRate / 100)}
                    strokeLinecap="round"
                  />
                </svg>
                <span className="absolute text-[11px] font-black text-white font-mono">
                  {utilizationRate.toFixed(0)}%
                </span>
              </div>
              <div className="space-y-1">
                <span className="text-xs font-bold text-white flex items-center gap-1.5">
                  <Activity className="text-accentOrange" size={13} />
                  Live Utilization
                </span>
                <p className="text-[10px] text-textFaint leading-normal">
                  {activeMeters} of {totalMeters} active taxi terminals are running rides right now.
                </p>
              </div>
            </div>

            {/* Stacked outcome distribution bar */}
            <div className="space-y-3">
              <span className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">Ride Outcome Spread</span>
              
              <div className="w-full h-4 bg-borderDark rounded-full overflow-hidden flex text-[8px] font-black text-black">
                {totalRidesCount === 0 ? (
                  <div className="w-full bg-[#1A1E26] text-textFaint text-center leading-4 font-semibold">No data</div>
                ) : (
                  <>
                    {completedRides.length > 0 && (
                      <div 
                        className="bg-blue-400 flex items-center justify-center" 
                        style={{ width: `${(completedRides.length / totalRidesCount) * 100}%` }}
                        title={`Completed: ${completedRides.length}`}
                      ></div>
                    )}
                    {runningRides.length > 0 && (
                      <div 
                        className="bg-emerald-400 flex items-center justify-center" 
                        style={{ width: `${(runningRides.length / totalRidesCount) * 100}%` }}
                        title={`Running: ${runningRides.length}`}
                      ></div>
                    )}
                    {cancelledRides.length > 0 && (
                      <div 
                        className="bg-red-400 flex items-center justify-center" 
                        style={{ width: `${(cancelledRides.length / totalRidesCount) * 100}%` }}
                        title={`Cancelled: ${cancelledRides.length}`}
                      ></div>
                    )}
                  </>
                )}
              </div>

              {/* Legends */}
              <div className="grid grid-cols-3 gap-2 text-[10px] font-semibold">
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded bg-blue-400"></div>
                  <span className="text-white">{completedRides.length} Done</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded bg-emerald-400"></div>
                  <span className="text-white">{runningRides.length} Active</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded bg-red-400"></div>
                  <span className="text-white">{cancelledRides.length} Cancel</span>
                </div>
              </div>
            </div>

          </div>
        </div>

      </div>

      {/* Bottom Section: Top performing receipts */}
      <div className="bg-panel border border-borderDark rounded-2xl p-6 space-y-4">
        <div>
          <h3 className="font-extrabold text-sm text-white flex items-center gap-1.5">
            <Award className="text-accentOrange" size={16} />
            Top Grossing Trips (All-Time)
          </h3>
          <p className="text-[10px] text-textFaint">Highest-ticket transactions recorded across the system.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {topTrips.length === 0 ? (
            <p className="text-xs text-textFaint py-4">No trips have been completed yet.</p>
          ) : (
            topTrips.map((t, idx) => (
              <div key={t.id} className="p-4 bg-cardColor/30 border border-borderDark rounded-xl space-y-2 relative">
                <div className="absolute top-3 right-3 text-textFaint/20 text-xl font-black">
                  #{idx + 1}
                </div>
                <div className="text-[10px] font-mono text-textFaint">Trip: {t.id}</div>
                <div className="text-xs font-semibold text-white/90">Driver: {getDriverName(t.driverId)}</div>
                <div className="flex items-baseline justify-between pt-2 border-t border-borderDark/40">
                  <span className="text-[10px] text-textFaint">Total Fare</span>
                  <span className="text-base font-black text-white font-mono">
                    ₱{t.totalFare.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

    </div>
  );
};
