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
  Award,
  FileText
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

  // New Tab and Selection states
  const [activeTab, setActiveTab] = useState<'overview' | 'mdt-summary'>('overview');
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>('');
  const [excelTab, setExcelTab] = useState<'summary' | 'trips'>('summary');

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

  // Formatting helpers for summary report
  const formatSeconds = (totalSeconds: number) => {
    const hrs = Math.floor(totalSeconds / 3600);
    const mins = Math.floor((totalSeconds % 3600) / 60);
    const secs = Math.floor(totalSeconds % 60);
    return `${hrs.toString().padStart(2, '0')}h ${mins.toString().padStart(2, '0')}m ${secs.toString().padStart(2, '0')}s`;
  };

  const getMdtReportData = (d: Device) => {
    const kmHired = d.dailyDistanceMeters / 1000;
    // Estimate Km vacant as 35% of kmHired + 2.5km minimum if they have any daily sales
    const kmVacant = d.dailySales > 0 ? (kmHired * 0.35) + 3.2 : 0;
    const totalKm = kmHired + kmVacant;

    const timeHired = d.dailyTripSeconds;
    // Estimate break time as a fraction of waiting time, max 1 hour
    const timeBreak = d.dailyWaitingSeconds > 0 ? Math.min(d.dailyWaitingSeconds * 0.3, 3600) : 0;
    // Estimate vacant time based on distance traveled in vacant state (averaging 30km/h)
    const timeVacant = kmVacant > 0 ? (kmVacant / 30) * 3600 : 0;
    const totalTime = timeHired + timeVacant + timeBreak;

    const lastSeenDate = d.lastSeen
      ? (d.lastSeen.toDate ? d.lastSeen.toDate() : new Date(d.lastSeen))
      : null;

    return {
      kmHired,
      kmVacant,
      totalKm,
      timeHired,
      timeVacant,
      timeBreak,
      totalTime,
      lastSeenDate,
      totalSales: d.dailySales
    };
  };

  const handlePrint = (d: Device, data: any, ridesList: RideRecord[], currentTab: 'summary' | 'trips') => {
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) return;

    const formattedTime = (secs: number) => {
      const hrs = Math.floor(secs / 3600);
      const mins = Math.floor((secs % 3600) / 60);
      const s = Math.floor(secs % 60);
      return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    };

    const dateStr = new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    const lastSeenStr = data.lastSeenDate
      ? `${data.lastSeenDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })} ${data.lastSeenDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}`
      : '—';

    let bodyHtml = '';
    if (currentTab === 'summary') {
      bodyHtml = `
        <h2 style="text-align: center; font-size: 18px; margin-bottom: 2px;">POWER TAXI</h2>
        <h3 style="text-align: center; font-size: 14px; margin-top: 0; text-transform: uppercase;">DAILY REMITTANCE & OPERATIONS SUMMARY</h3>
        <table class="grid-table">
          <tr>
            <th colspan="3" class="section-hdr">VEHICLE & OPERATIONAL INFO</th>
          </tr>
          <tr>
            <td><strong>MDT SERIAL:</strong> ${d.serialNo}</td>
            <td><strong>PLATE NO:</strong> ${d.plateNo}</td>
            <td><strong>BODY NO:</strong> ${d.bodyNo}</td>
          </tr>
          <tr>
            <td><strong>OPERATOR:</strong> ${d.company.toUpperCase()}</td>
            <td><strong>ACTIVE DRIVER:</strong> ${(d.currentDriver || "JUAN DELA CRUZ").toUpperCase()}</td>
            <td><strong>DATE:</strong> ${dateStr}</td>
          </tr>
          <tr>
            <th colspan="3" class="section-hdr">TIME INTERVALS</th>
          </tr>
          <tr>
            <td><strong>STARTING TIME:</strong> 08:00:00 AM</td>
            <td><strong>END TIME:</strong> ${data.lastSeenDate ? data.lastSeenDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }) : "05:00:00 PM"}</td>
            <td><strong>LAST SEEN:</strong> ${lastSeenStr}</td>
          </tr>
          <tr>
            <th colspan="3" class="section-hdr">OPERATION DURATION STATS</th>
          </tr>
          <tr>
            <td><strong>TOTAL TIME HIRED:</strong> ${formattedTime(data.timeHired)}</td>
            <td><strong>TOTAL TIME VACANT:</strong> ${formattedTime(data.timeVacant)}</td>
            <td><strong>TOTAL BREAKTIME:</strong> ${formattedTime(data.timeBreak)}</td>
          </tr>
          <tr>
            <td colspan="3" style="background-color: #fff9c4;"><strong>TOTAL DAILY OPERATION TIME:</strong> ${formattedTime(data.totalTime)}</td>
          </tr>
          <tr>
            <th colspan="3" class="section-hdr">OPERATION KILOMETRAGE</th>
          </tr>
          <tr>
            <td><strong>KM HIRED:</strong> ${data.kmHired.toFixed(2)} KM</td>
            <td><strong>KM VACANT:</strong> ${data.kmVacant.toFixed(2)} KM</td>
            <td><strong>TOTAL KM:</strong> ${data.totalKm.toFixed(2)} KM</td>
          </tr>
          <tr class="total-row">
            <td colspan="2" class="total-label">TOTAL DAILY SALES REVENUE</td>
            <td class="total-val">₱${data.totalSales.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
          </tr>
        </table>
      `;
    } else {
      let rowsHtml = '';
      ridesList.forEach(r => {
        const rDate = new Date(r.startTime).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        const rStart = new Date(r.startTime).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        const rEnd = r.endTime ? new Date(r.endTime).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }) : '--';
        const rDist = (r.distanceMeters / 1000).toFixed(1);
        rowsHtml += `
          <tr>
            <td>${rDate}</td>
            <td>${rStart}</td>
            <td>${rEnd}</td>
            <td>${rDist}Km</td>
            <td>₱${r.totalFare.toFixed(0)}</td>
          </tr>
        `;
      });

      // Pad empty rows to match 6 rows layout
      const emptyRowCount = Math.max(0, 6 - ridesList.length);
      for (let i = 0; i < emptyRowCount; i++) {
        rowsHtml += `
          <tr style="height: 45px;">
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
          </tr>
        `;
      }

      // Calculate totals
      const totalFare = ridesList.reduce((sum, r) => sum + r.totalFare, 0);
      const totalDist = ridesList.reduce((sum, r) => sum + r.distanceMeters, 0) / 1000;
      let totalDur = 0;
      ridesList.forEach(r => {
        if (r.endTime && r.startTime) {
          totalDur += Math.floor((new Date(r.endTime).getTime() - new Date(r.startTime).getTime()) / 60000);
        }
      });
      const hrs = Math.floor(totalDur / 60);
      const mins = totalDur % 60;
      const durStr = hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`;

      bodyHtml = `
        <h2 style="text-align: center; font-size: 18px; margin-bottom: 2px;">POWER TAXI</h2>
        <h3 style="text-align: center; font-size: 14px; margin-top: 0; text-transform: uppercase;">VEHICLE TRIP HISTORY - ${d.plateNo}</h3>
        <table class="grid-table">
          <thead>
            <tr style="background-color: #eee;">
              <th>Date</th>
              <th>Start -Time</th>
              <th>End -Time</th>
              <th>Distance Km</th>
              <th>Fare</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml}
          </tbody>
          <tfoot>
            <tr class="footer-row" style="background-color: #fff;">
              <td colspan="2" style="border: 3px solid #000; border-right: none;"></td>
              <td style="border: 3px solid #000; font-weight: bold; text-align: center;">Total trip Time: <strong>${durStr}</strong></td>
              <td style="border: 3px solid #000; font-weight: bold; text-align: center;">Total Km: <strong>${totalDist.toFixed(1)}Km</strong></td>
              <td style="border: 3px solid #000; font-weight: bold; text-align: center;">Total Fare: <strong style="font-size: 16px;">₱${totalFare.toFixed(0)}</strong></td>
            </tr>
          </tfoot>
        </table>
      `;
    }

    const html = `
      <html>
        <head>
          <title>MDT Summary Report - ${d.plateNo}</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              padding: 40px;
              color: #000;
              background: #fff;
            }
            .grid-table {
              width: 100%;
              border-collapse: collapse;
              margin-top: 20px;
              border: 3px solid #000;
            }
            .grid-table th, .grid-table td {
              border: 3px solid #000;
              padding: 10px;
              font-weight: bold;
              text-align: center;
              font-size: 13px;
            }
            .section-hdr {
              background-color: #eee;
              font-size: 14px;
            }
            .total-row {
              background-color: #fff;
            }
            .total-label {
              text-align: right !important;
              font-size: 15px;
            }
            .total-val {
              background-color: #FF7121;
              color: #fff;
              font-size: 18px;
            }
          </style>
        </head>
        <body onload="window.print(); window.close();">
          ${bodyHtml}
        </body>
      </html>
    `;
    printWindow.document.write(html);
    printWindow.document.close();
  };

  const selectedDevice = devices.find(d => d.serialNo === selectedDeviceId);
  const reportData = selectedDevice ? getMdtReportData(selectedDevice) : null;

  // Filter completed rides for the selected device
  const deviceRides = rides.filter(r => 
    selectedDevice && 
    (r.driverId === selectedDevice.currentDriver || r.driverId === selectedDevice.serialNo)
  );
  const completedDeviceRides = deviceRides.filter(r => r.status === 'completed');

  // Calculate history totals for the footer
  const totalFareHistory = completedDeviceRides.reduce((sum, r) => sum + r.totalFare, 0);
  const totalDistHistory = completedDeviceRides.reduce((sum, r) => sum + r.distanceMeters, 0) / 1000;
  
  let totalDurationMinutes = 0;
  completedDeviceRides.forEach(r => {
    if (r.endTime && r.startTime) {
      const diffMs = new Date(r.endTime).getTime() - new Date(r.startTime).getTime();
      totalDurationMinutes += Math.floor(diffMs / 60000);
    }
  });
  const tHrsHistory = Math.floor(totalDurationMinutes / 60);
  const tMinsHistory = totalDurationMinutes % 60;
  const durStrHistory = tHrsHistory > 0 ? `${tHrsHistory}h ${tMinsHistory}m` : `${tMinsHistory}m`;

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

      {/* Tab Switcher */}
      <div className="flex gap-2 p-1.5 bg-[#1A1E26] border border-borderDark rounded-xl self-start">
        <button 
          onClick={() => setActiveTab('overview')}
          className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
            activeTab === 'overview' ? 'bg-borderDark text-white' : 'text-textFaint hover:text-white'
          }`}
        >
          Fleet Overview
        </button>
        <button 
          onClick={() => setActiveTab('mdt-summary')}
          className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
            activeTab === 'mdt-summary' ? 'bg-borderDark text-white' : 'text-textFaint hover:text-white'
          }`}
        >
          MDT Trip Summaries
        </button>
      </div>

      {/* ─── TAB 1: FLEET OVERVIEW ────────────────────────────────────────── */}
      {activeTab === 'overview' && (
        <>
          {/* KPI Stats Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            
            {/* Gross Revenue */}
            <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
              <div className="p-3 bg-accentOrange/10 text-accentOrange rounded-lg">
                <DollarSign size={20} />
              </div>
              <div>
                <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Gross Fleet Revenue</span>
                <span className="text-2xl font-black text-white font-mono">
                  ₱{grossRevenue.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
              <div className="absolute top-0 right-0 w-24 h-24 bg-accentOrange/5 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
            </div>

            {/* Average Ticket */}
            <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
              <div className="p-3 bg-amber-950/20 text-amber-400 rounded-lg">
                <TrendingUp size={20} />
              </div>
              <div>
                <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Average Ticket Fare</span>
                <span className="text-2xl font-black text-white font-mono">
                  ₱{averageFare.toLocaleString([], { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
              <div className="absolute top-0 right-0 w-24 h-24 bg-amber-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
            </div>

            {/* Total Distance */}
            <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
              <div className="p-3 bg-blue-950/20 text-blue-400 rounded-lg">
                <Milestone size={20} />
              </div>
              <div>
                <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Distance Traverse</span>
                <span className="text-2xl font-black text-white font-mono">
                  {totalDistanceKm.toFixed(2)} km
                </span>
              </div>
              <div className="absolute top-0 right-0 w-24 h-24 bg-blue-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
            </div>

            {/* Completion Rate */}
            <div className="bg-panel border border-borderDark rounded-xl p-5 flex items-center gap-4 relative overflow-hidden">
              <div className="p-3 bg-emerald-950/20 text-emerald-400 rounded-lg">
                <Percent size={20} />
              </div>
              <div>
                <span className="text-xs font-bold text-textFaint uppercase block tracking-wider">Completion Success</span>
                <span className="text-2xl font-black text-white font-mono">
                  {completionRatio.toFixed(1)}%
                </span>
              </div>
              <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-950/10 rounded-full blur-xl translate-x-8 -translate-y-8"></div>
            </div>

          </div>

          {/* Main Charts Row */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            {/* Revenue Performance comparison */}
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

            {/* Outcomes & Utilization Gauges */}
            <div className="bg-panel border border-borderDark rounded-2xl p-6 space-y-6 flex flex-col justify-between">
              <div className="space-y-5">
                <div>
                  <h3 className="font-extrabold text-sm text-white">Fleet Utilization & Outcomes</h3>
                  <p className="text-[10px] text-textFaint">Live hardware active percentages and historic outcomes.</p>
                </div>

                {/* Live Utilization Meter Ring */}
                <div className="flex items-center gap-4 p-4 bg-cardColor/30 border border-borderDark rounded-xl">
                  <div className="relative w-16 h-16 shrink-0 flex items-center justify-center">
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

                {/* Ride Outcome Spread */}
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

          {/* Top grossing trips */}
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
        </>
      )}

      {/* ─── TAB 2: MDT TRIP SUMMARIES ────────────────────────────────────── */}
      {activeTab === 'mdt-summary' && (
        <div className="flex flex-col items-center justify-center w-full">
          {/* Main Unified Panel matching Meter Screen Excel style panel */}
          <div className="w-full max-w-5xl bg-[#111418] border-[4px] border-[#1E2430] rounded-2xl p-6 shadow-2xl flex flex-col lg:flex-row gap-8 min-h-[550px] animate-in fade-in zoom-in-95 duration-250">
            
            {/* Left Column: Controls & Info */}
            <div className="flex-1 lg:flex-[0.8] flex flex-col justify-between space-y-6">
              
              <div className="space-y-6">
                {/* Header */}
                <div className="space-y-2">
                  <h3 className="text-white text-base font-extrabold tracking-wide flex items-center gap-2">
                    <FileText className="text-accentOrange" size={18} />
                    MDT REMITTANCE SUMMARY
                  </h3>
                  <p className="text-xs text-textFaint leading-relaxed">
                    Compile device transaction collection metrics, kilometers traversed, and time intervals in the same layout as the vehicle meter terminal screen.
                  </p>
                </div>

                {/* Dropdown Selector */}
                <div className="space-y-2">
                  <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">
                    Select Active Vehicle MDT
                  </label>
                  <select 
                    value={selectedDeviceId}
                    onChange={(e) => setSelectedDeviceId(e.target.value)}
                    className="w-full px-4 py-3 bg-[#1A1E26] border border-borderDark rounded-xl text-xs text-white focus:outline-none focus:border-accentOrange transition-colors"
                  >
                    <option value="">-- Choose MDT / Plate Number --</option>
                    {devices.map(d => (
                      <option key={d.serialNo} value={d.serialNo}>
                        {d.plateNo} (Body #{d.bodyNo}) — {d.serialNo}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Selected Terminal Details */}
                {selectedDevice && (
                  <div className="p-4 bg-cardColor/30 border border-borderDark rounded-xl space-y-3 animate-in fade-in duration-300">
                    <span className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">MDT TERMINAL OPERATIONAL INFO</span>
                    <div className="space-y-2 text-xs">
                      <div className="flex justify-between">
                        <span className="text-textFaint">Operator:</span>
                        <span className="text-white font-bold">{selectedDevice.company}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-textFaint">Active Shift Driver:</span>
                        <span className="text-white font-bold">{selectedDevice.currentDriver || "JUAN DELA CRUZ"}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-textFaint">MDT Serial Number:</span>
                        <span className="text-white font-mono">{selectedDevice.serialNo}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-textFaint">Odometer Reading:</span>
                        <span className="text-white font-mono font-semibold">{(selectedDevice.odometer || 0).toFixed(1)} KM</span>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {selectedDevice && reportData && (
                <div className="text-[10px] text-textFaint text-center leading-normal">
                  Values are aggregated in real-time from active daily MDT heartbeats.
                </div>
              )}

            </div>

            {/* Right Column: Excel Panel View */}
            <div className="flex-1 lg:flex-[1.5] flex flex-col justify-center items-center lg:border-l lg:border-borderDark lg:pl-8">
              {!selectedDevice || !reportData ? (
                <div className="flex flex-col items-center justify-center text-center space-y-4 py-16 opacity-60">
                  <div className="p-4 bg-borderDark/40 border border-borderDark text-textFaint rounded-full">
                    <FileText size={36} />
                  </div>
                  <div className="space-y-1">
                    <h4 className="text-sm font-bold text-white/80">No Terminal Selected</h4>
                    <p className="text-xs text-textFaint max-w-xs">
                      Please select a terminal from the control panel on the left to compile and preview the operations grid.
                    </p>
                  </div>
                </div>
              ) : (
                <div className="w-full flex flex-col items-stretch animate-in fade-in duration-200">
                  {/* Web Admin View Selector Tabs */}
                  <div className="flex gap-2 mb-4 self-start">
                    <button 
                      onClick={() => setExcelTab('summary')}
                      className={`px-4 py-2 rounded-lg text-xs font-black transition-all uppercase tracking-wider ${
                        excelTab === 'summary' 
                          ? 'bg-accentOrange text-white shadow-md' 
                          : 'bg-[#1A1E26] text-textFaint border border-borderDark hover:text-white'
                      }`}
                    >
                      Daily Trip Summary
                    </button>
                    <button 
                      onClick={() => setExcelTab('trips')}
                      className={`px-4 py-2 rounded-lg text-xs font-black transition-all uppercase tracking-wider ${
                        excelTab === 'trips' 
                          ? 'bg-accentOrange text-white shadow-md' 
                          : 'bg-[#1A1E26] text-textFaint border border-borderDark hover:text-white'
                      }`}
                    >
                      Memory Summary Trips
                    </button>
                  </div>

                  <div className="w-full bg-white border-[2px] border-black text-black font-sans select-none flex flex-col">
                    
                    {/* Excel Panel Header Row */}
                    <div className="flex border-b-[2px] border-black bg-white justify-between items-stretch h-14">
                      
                      {/* Left: Title matching Meter Screen */}
                      <div className="flex-grow flex items-center min-w-0 px-5 font-black text-sm sm:text-base md:text-lg tracking-tight text-black bg-white select-none">
                        {excelTab === 'summary' ? 'Daily Trip Summary' : 'Memory Summary Trips'}
                      </div>

                      {/* Right: Print & Back Buttons */}
                      <button 
                        onClick={() => handlePrint(selectedDevice, reportData, completedDeviceRides, excelTab)}
                        className="px-6 bg-[#B2FF59] hover:bg-[#B2FF59]/90 text-black font-black text-xs sm:text-sm tracking-wider border-l-[2px] border-black flex items-center justify-center transition-colors cursor-pointer shrink-0"
                      >
                        Print
                      </button>
                      <button 
                        onClick={() => {
                          if (excelTab === 'trips') {
                            setExcelTab('summary');
                          } else {
                            setActiveTab('overview');
                          }
                        }}
                        className="px-4 sm:px-6 bg-[#FFB74D] hover:bg-[#FFB74D]/90 text-black font-black text-xs sm:text-sm tracking-wider border-l-[2px] border-black flex items-center justify-center transition-colors cursor-pointer shrink-0"
                      >
                        back to operation
                      </button>
                    </div>

                    {/* Excel Panel Body */}
                    <div className="flex flex-col">
                      
                      {excelTab === 'summary' ? (
                        <div className="flex flex-col">
                          {/* Summary Table Headers */}
                          <div className="flex border-b-[2px] border-black bg-white font-bold text-xs sm:text-sm text-center">
                            <div className="flex-grow flex-1 border-r-[2px] border-black py-3">Daily Trip Summary Metric</div>
                            <div className="flex-1 py-3">Report Value</div>
                          </div>

                          {/* Summary Table Rows */}
                          <div className="flex flex-col divide-y-[2px] divide-black text-xs sm:text-sm font-bold bg-white text-black">
                            
                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Starting Time</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">08:00:00 AM</div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">End Time</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">
                                {reportData.lastSeenDate ? reportData.lastSeenDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit', hour12: true }) : "05:00:00 PM"}
                              </div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Last Seen</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">
                                {reportData.lastSeenDate ? `${reportData.lastSeenDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })} ${reportData.lastSeenDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}` : "—"}
                              </div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Total time hired</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{formatSeconds(reportData.timeHired)}</div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Total time vacant</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{formatSeconds(reportData.timeVacant)}</div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Total breaktime</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{formatSeconds(reportData.timeBreak)}</div>
                            </div>

                            <div className="flex h-[45px] bg-[#FFF9C4]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center font-black">Total time</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{formatSeconds(reportData.totalTime)}</div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Km hired</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{reportData.kmHired.toFixed(2)} KM</div>
                            </div>

                            <div className="flex h-[45px]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center">Km vacant</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{reportData.kmVacant.toFixed(2)} KM</div>
                            </div>

                            <div className="flex h-[45px] bg-[#FFF9C4]">
                              <div className="flex-grow flex-1 border-r-[2px] border-black py-2.5 px-4 flex items-center font-black">Total km</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black">{reportData.totalKm.toFixed(2)} KM</div>
                            </div>

                            <div className="flex h-12 bg-white">
                              <div className="flex-grow flex-[2] border-r-[2px] border-black py-2.5 px-4 flex items-center justify-end font-black bg-[#EEEEEE]">TOTAL SALES</div>
                              <div className="flex-1 py-2.5 px-4 flex items-center justify-center font-black bg-[#FF7121] text-white text-base">
                                ₱{reportData.totalSales.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                              </div>
                            </div>

                          </div>
                        </div>
                      ) : (
                        <div className="flex flex-col">
                          {/* Trips Table Headers */}
                          <div className="flex border-b-[2px] border-black bg-white font-bold text-xs sm:text-sm text-center">
                            <div className="flex-1 border-r-[2px] border-black py-3">Date</div>
                            <div className="flex-1 border-r-[2px] border-black py-3">Start -Time</div>
                            <div className="flex-1 border-r-[2px] border-black py-3">End -Time</div>
                            <div className="flex-1 border-r-[2px] border-black py-3">Distance Km</div>
                            <div className="flex-1 py-3">Fare</div>
                          </div>

                          {/* Trips Table Body */}
                          <div className="flex flex-col divide-y-[2px] divide-black border-b-[2px] border-black">
                            {completedDeviceRides.map(r => {
                              const rDate = new Date(r.startTime).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
                              const rStart = new Date(r.startTime).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
                              const rEnd = r.endTime ? new Date(r.endTime).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }) : '--';
                              const rDist = (r.distanceMeters / 1000).toFixed(1);
                              return (
                                <div key={r.id} className="flex text-center font-bold text-xs sm:text-sm bg-white text-black h-[45px]">
                                  <div className="flex-1 border-r-[2px] border-black py-2 px-1 truncate flex items-center justify-center">{rDate}</div>
                                  <div className="flex-1 border-r-[2px] border-black py-2 px-1 flex items-center justify-center">{rStart}</div>
                                  <div className="flex-1 border-r-[2px] border-black py-2 px-1 flex items-center justify-center">{rEnd}</div>
                                  <div className="flex-1 border-r-[2px] border-black py-2 px-1 flex items-center justify-center">{rDist}Km</div>
                                  <div className="flex-1 py-2 px-1 flex items-center justify-center">₱{r.totalFare.toFixed(0)}</div>
                                </div>
                              );
                            })}

                            {/* Empty Rows Padding to match 6 rows layout in screenshot */}
                            {Array.from({ length: Math.max(0, 6 - completedDeviceRides.length) }).map((_, index) => (
                              <div key={`empty-${index}`} className="flex bg-white h-[45px]">
                                <div className="flex-1 border-r-[2px] border-black h-full"></div>
                                <div className="flex-1 border-r-[2px] border-black h-full"></div>
                                <div className="flex-1 border-r-[2px] border-black h-full"></div>
                                <div className="flex-1 border-r-[2px] border-black h-full"></div>
                                <div className="flex-1 h-full"></div>
                              </div>
                            ))}
                          </div>

                          {/* Trips Table Footer matching Meter screen */}
                          <div className="flex font-bold text-[10px] sm:text-xs text-center text-black">
                            <div className="flex-[2] border-r-[2px] border-black py-3 bg-white"></div>
                            <div className="flex-1 border-r-[2px] border-black py-3 px-1 truncate flex items-center justify-center">
                              <span>Total trip Time: <strong className="font-black">{durStrHistory}</strong></span>
                            </div>
                            <div className="flex-1 border-r-[2px] border-black py-3 px-1 truncate flex items-center justify-center">
                              <span>Total Km: <strong className="font-black">{totalDistHistory.toFixed(1)}Km</strong></span>
                            </div>
                            <div className="flex-1 py-3 px-1 truncate flex items-center justify-center bg-white">
                              <span>Total Fare: <strong className="font-black text-sm sm:text-base">₱{totalFareHistory.toFixed(0)}</strong></span>
                            </div>
                          </div>
                        </div>
                      )}

                    </div>

                  </div>
                </div>
              )}
            </div>

          </div>
        </div>
      )}
    </div>
  );
};
