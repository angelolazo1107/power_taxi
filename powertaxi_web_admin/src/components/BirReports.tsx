import React, { useState, useEffect } from 'react';
import { subscribeToAllRides, subscribeToDevices, subscribeToCompanies, subscribeToUsers } from '../services/firebase';
import type { RideRecord, Device, Company, AppUser } from '../services/firebase';
import { 
  Filter,
  Search,
  Download,
  Printer,
  Smartphone,
  Bus,
  User,
  FileText,
  BookOpen,
  Tag,
  Accessibility
} from 'lucide-react';

interface BirReportsProps {
  selectedCompanyId: string | null;
}

interface ZReadingRecord {
  id: string;
  date: string;
  dispatchNo: string;
  deviceName: string;
  zReadingDateTime: string;
  plateNo: string;
  bodyNo: string;
  beginningSiOrNo: string;
  endingSiOrNo: string;
  noOfTxn: number;
  startRefundTicketNo: string;
  endRefundTicketNo: string;
  grossSales: number;
  refund: number;
  discount: number;
  netSales: number;
  accSalesOpen: number;
  accSalesClose: number;
  companyName: string;
  companyId: string;
  zCount: string;
  tktResetCount: number;
  accSalesResetCount: number;
  vatableSales: number;
  vatAmount: number;
  vatExemptSales: number;
  zeroRatedSales: number;
  discountSC: number;
  discountPWD: number;
  discountStudent: number;
  discountOthers: number;
  refunds: number;
  voids: number;
  totalDeduction: number;
  vatAdjSC: number;
  vatAdjPWD: number;
  vatAdjStudent: number;
  vatAdjOthers: number;
  vatOnRefunds: number;
  vatAdjTotal: number;
  vatPayable: number;
  salesOverrun: number;
  remarks: string;
}

export const BirReports: React.FC<BirReportsProps> = ({ selectedCompanyId }) => {
  const [rides, setRides] = useState<RideRecord[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [loading, setLoading] = useState(true);

  // Filter States
  const [datePeriod, setDatePeriod] = useState<'today' | 'yesterday' | 'this_week' | 'last_week' | 'this_month' | 'last_month' | 'all_time' | 'custom'>('yesterday');
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');
  
  const [selectedDeviceSerial, setSelectedDeviceSerial] = useState('all');
  const [selectedVehiclePlate, setSelectedVehiclePlate] = useState('all');
  const [selectedDriverId, setSelectedDriverId] = useState('all');
  
  const [activeTab, setActiveTab] = useState<'summary' | 'x_reading' | 'sc_book' | 'students_book' | 'pwd_book' | 'other_discounts'>('summary');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState<'summary' | 'full'>('summary');

  // Fetch Firestore data
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

  // Generate date bounds
  const getDateBounds = () => {
    const now = new Date();
    const start = new Date(now);
    const end = new Date(now);

    switch (datePeriod) {
      case 'today':
        start.setHours(0, 0, 0, 0);
        end.setHours(23, 59, 59, 999);
        break;
      case 'yesterday':
        start.setDate(now.getDate() - 1);
        start.setHours(0, 0, 0, 0);
        end.setDate(now.getDate() - 1);
        end.setHours(23, 59, 59, 999);
        break;
      case 'this_week':
        const dayOfWeek = now.getDay();
        start.setDate(now.getDate() - dayOfWeek);
        start.setHours(0, 0, 0, 0);
        end.setHours(23, 59, 59, 999);
        break;
      case 'last_week':
        const currentDayOfWeek = now.getDay();
        start.setDate(now.getDate() - currentDayOfWeek - 7);
        start.setHours(0, 0, 0, 0);
        end.setDate(now.getDate() - currentDayOfWeek - 1);
        end.setHours(23, 59, 59, 999);
        break;
      case 'this_month':
        start.setDate(1);
        start.setHours(0, 0, 0, 0);
        end.setHours(23, 59, 59, 999);
        break;
      case 'last_month':
        start.setMonth(now.getMonth() - 1);
        start.setDate(1);
        start.setHours(0, 0, 0, 0);
        end.setDate(0); // Last day of previous month
        end.setHours(23, 59, 59, 999);
        break;
      case 'custom':
        if (customStartDate) start.setTime(new Date(customStartDate).getTime());
        if (customEndDate) end.setTime(new Date(customEndDate).getTime());
        break;
      case 'all_time':
      default:
        start.setTime(0); // Beginning of time
        break;
    }
    return { start, end };
  };

  // Build Z-Reading records purely from real Firestore ride data — no mock data.
  const generateZReadings = (): ZReadingRecord[] => {
    const { start, end } = getDateBounds();

    // Group rides by (date, device serial)
    const groups: Record<string, { rides: RideRecord[]; dateStr: string; deviceSerial: string }> = {};

    rides.forEach(r => {
      const rideDate = new Date(r.startTime);
      if (rideDate < start || rideDate > end) return;

      const dateStr = rideDate.toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
      // Use the device serial stored on the ride record (saved by the mobile app at ride start)
      const deviceSerial = r.deviceSerialNo || 'UNKNOWN';

      const key = `${dateStr}_${deviceSerial}`;
      if (!groups[key]) groups[key] = { rides: [], dateStr, deviceSerial };
      groups[key].rides.push(r);
    });

    const records: ZReadingRecord[] = [];

    Object.keys(groups).forEach((key, index) => {
      const group = groups[key];
      const completed = group.rides.filter(r => r.status === 'completed');
      const cancelled = group.rides.filter(r => r.status === 'cancelled');

      const txnNo = completed.length;
      if (txnNo === 0) return;

      // Z-reading time: use the actual end time of the last completed ride for this day/device
      const lastEndTime = completed.reduce<string | null>((latest, r) => {
        if (!r.endTime) return latest;
        return !latest || r.endTime > latest ? r.endTime : latest;
      }, null);
      const zReadingTime = lastEndTime
        ? (() => {
            const d = new Date(lastEndTime);
            return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
          })()
        : '20:00:00';

      const device = devices.find(d => d.serialNo === group.deviceSerial);
      const company = companies.find(c => c.id === device?.companyId);

      // Use plate/body from the ride record first (saved at ride start), then device fallback
      const recPlateNo = completed[0]?.plateNo || device?.plateNo || '—';
      const recBodyNo  = completed[0]?.bodyNo  || device?.bodyNo  || '—';

      const gross   = completed.reduce((s, r) => s + (r.grossFare ?? r.totalFare), 0);
      const refundAmt = cancelled.reduce((s, r) => s + r.totalFare, 0);

      // Derive discount amounts from ride discountType + discountAmount fields
      const scAmt      = completed.reduce((s, r) => s + (r.discountType === 'SC'      ? (r.discountAmount ?? 0) : 0), 0);
      const pwdAmt     = completed.reduce((s, r) => s + (r.discountType === 'PWD'     ? (r.discountAmount ?? 0) : 0), 0);
      const studentAmt = completed.reduce((s, r) => s + (r.discountType === 'STUDENT' ? (r.discountAmount ?? 0) : 0), 0);
      const othersAmt  = completed.reduce((s, r) => s + (!['REGULAR','SC','PWD','STUDENT'].includes(r.discountType ?? 'REGULAR') ? (r.discountAmount ?? 0) : 0), 0);
      const totalDisc  = scAmt + pwdAmt + studentAmt + othersAmt;
      const net        = gross - refundAmt - totalDisc;

      // Accumulated sales — derived from running total across groups (ordered by date)
      const priorNet = records.reduce((s, r) => s + r.netSales, 0);

      records.push({
        id: `zread_${key}`,
        date: group.dateStr,
        dispatchNo: `${String(index + 1).padStart(6, '0')}`,
        deviceName: group.deviceSerial,
        zReadingDateTime: `${group.dateStr} ${zReadingTime}`,
        plateNo: recPlateNo,
        bodyNo:  recBodyNo,
        beginningSiOrNo: String(completed[0]?.orNumber ?? '—'),
        endingSiOrNo:    String(completed[completed.length - 1]?.orNumber ?? '—'),
        noOfTxn: txnNo,
        startRefundTicketNo: refundAmt > 0 ? String(cancelled[0]?.orNumber ?? '—') : '—',
        endRefundTicketNo:   refundAmt > 0 ? String(cancelled[cancelled.length - 1]?.orNumber ?? '—') : '—',
        grossSales:      gross,
        refund:          refundAmt,
        discount:        totalDisc,
        netSales:        net,
        accSalesOpen:    priorNet,
        accSalesClose:   priorNet + net,
        companyName:     company?.name   || device?.company || '—',
        companyId:       device?.companyId || '',
        zCount:          `#${String(index + 1).padStart(3, '0')}`,
        tktResetCount:      0,
        accSalesResetCount: 0,
        vatableSales:    0,
        vatAmount:       0,
        vatExemptSales:  gross,
        zeroRatedSales:  0,
        discountSC:      scAmt,
        discountPWD:     pwdAmt,
        discountStudent: studentAmt,
        discountOthers:  othersAmt,
        refunds:         refundAmt,
        voids:           0,
        totalDeduction:  totalDisc + refundAmt,
        vatAdjSC:        0,
        vatAdjPWD:       0,
        vatAdjStudent:   0,
        vatAdjOthers:    0,
        vatOnRefunds:    0,
        vatAdjTotal:     0,
        vatPayable:      0,
        salesOverrun:    0,
        remarks:         'Normal Operations',
      });
    });

    return records;
  };

  // Perform full filtering logic (Date, Device, Vehicle, Company Scope, Search Query)
  const allZReadings = generateZReadings();

  const filteredZReadings = allZReadings.filter(rec => {
    // 1. Company Scope
    if (selectedCompanyId && rec.companyId !== selectedCompanyId) return false;

    // 2. Device filter
    if (selectedDeviceSerial !== 'all' && rec.deviceName !== selectedDeviceSerial) return false;

    // 3. Vehicle plate filter
    if (selectedVehiclePlate !== 'all' && rec.plateNo !== selectedVehiclePlate) return false;

    // 4. Driver filter (simulate driver scoping)
    if (selectedDriverId !== 'all') {
      const deviceForDriver = devices.find(d => d.currentDriver === selectedDriverId);
      if (!deviceForDriver || rec.deviceName !== deviceForDriver.serialNo) return false;
    }

    // 5. Search query
    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      return (
        rec.deviceName.toLowerCase().includes(q) ||
        rec.plateNo.toLowerCase().includes(q) ||
        rec.dispatchNo.toLowerCase().includes(q) ||
        rec.companyName.toLowerCase().includes(q) ||
        rec.remarks.toLowerCase().includes(q)
      );
    }

    return true;
  });

  // KPI Calculations
  const totalTxn = filteredZReadings.reduce((sum, r) => sum + r.noOfTxn, 0);
  const totalGross = filteredZReadings.reduce((sum, r) => sum + r.grossSales, 0);
  const totalRefund = filteredZReadings.reduce((sum, r) => sum + r.refund, 0);
  const totalDiscount = filteredZReadings.reduce((sum, r) => sum + r.discount, 0);
  const totalNet = filteredZReadings.reduce((sum, r) => sum + r.netSales, 0);

  // Build discount log records from real ride data for SC/PWD/Student books.
  // Each ride record may carry typed discount fields; only include rides with the relevant discount.
  const getDiscountsBookData = (type: 'SC' | 'PWD' | 'STUDENT') => {
    const list: any[] = [];
    const { start, end } = getDateBounds();

    rides.forEach(r => {
      const rideDate = new Date(r.startTime);
      if (rideDate < start || rideDate > end) return;
      if (r.status !== 'completed') return;

      // Only include rides with a matching discount type and a non-zero discount amount
      if (r.discountType !== type) return;
      const discAmt = r.discountAmount ?? 0;
      if (discAmt <= 0) return;

      const dateStr = rideDate.toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
      const gross = r.grossFare ?? r.totalFare;

      list.push({
        date: dateStr,
        ticketNo:   r.orNumber ?? '—',
        idNo:       '—',  // passenger ID not captured by the mobile device
        name:       '—',  // passenger name not captured by the mobile device
        grossSales: gross,
        discount:   discAmt,
        netSales:   gross - discAmt,
        deviceName: r.deviceSerialNo ?? '—',
        plateNo:    r.plateNo ?? '—',
        schoolName: type === 'STUDENT' ? '—' : undefined,
      });
    });

    return list;
  };

  // X-Reading: real hourly data derived directly from rides (not fabricated from Z-readings)
  interface XReadingRow {
    date: string;
    hourBlock: string;
    deviceName: string;
    plateNo: string;
    companyName: string;
    grossSales: number;
    netSales: number;
    txnCount: number;
  }

  const generateXReadings = (): XReadingRow[] => {
    const { start, end } = getDateBounds();
    const groups: Record<string, XReadingRow> = {};

    rides.forEach(r => {
      if (r.status !== 'completed') return;
      const rideDate = new Date(r.startTime);
      if (rideDate < start || rideDate > end) return;

      const dateStr = rideDate.toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
      const hour = rideDate.getHours();
      const hourBlock = `${String(hour).padStart(2, '0')}:00–${String(hour + 1).padStart(2, '0')}:00`;
      const deviceSerial = r.deviceSerialNo || 'UNKNOWN';

      // Apply device filter if set
      if (selectedDeviceSerial !== 'all' && deviceSerial !== selectedDeviceSerial) return;

      const device = devices.find(d => d.serialNo === deviceSerial);
      const company = companies.find(c => c.id === device?.companyId);

      const key = `${dateStr}_${hour}_${deviceSerial}`;
      if (!groups[key]) {
        groups[key] = {
          date: dateStr,
          hourBlock,
          deviceName: deviceSerial,
          plateNo: r.plateNo || device?.plateNo || '—',
          companyName: company?.name || device?.company || '—',
          grossSales: 0,
          netSales: 0,
          txnCount: 0,
        };
      }
      const gross = r.grossFare ?? r.totalFare;
      const disc  = r.discountAmount ?? 0;
      groups[key].grossSales += gross;
      groups[key].netSales   += gross - disc;
      groups[key].txnCount   += 1;
    });

    return Object.values(groups).sort((a, b) =>
      a.date.localeCompare(b.date) || a.hourBlock.localeCompare(b.hourBlock)
    );
  };

  // CSV Export Utility
  const handleExport = () => {
    let headers: string[] = [];
    let rows: string[][] = [];
    let filename = `BIR_${activeTab}_Report.csv`;

    if (activeTab === 'summary') {
      headers = [
        'Date', 'Dispatch No', 'Device Name', 'Z-Reading Date Time', 'Plate/Body No', 
        'Beginning SI/OR No', 'Ending SI/OR No', 'No of Txn', 'Start Refund Ticket #', 'End Refund Ticket #',
        'Gross Sales', 'Refund', 'Discount', 'Net Sales', 'Acc Sales Open', 'Acc Sales Close',
        'Company Name', 'Z-Count', 'Tkt Reset Count', 'Acc Sales Reset Count',
        'Vatable Sales', 'Vat Amount', 'Vat-Exempt Sales', 'Zero-Rated Sales',
        'SC Discount', 'PWD Discount', 'Student Discount', 'Total Deduction', 'Remarks'
      ];
      rows = filteredZReadings.map(r => [
        r.date, r.dispatchNo, r.deviceName, r.zReadingDateTime, r.plateNo,
        r.beginningSiOrNo, r.endingSiOrNo, String(r.noOfTxn), r.startRefundTicketNo, r.endRefundTicketNo,
        r.grossSales.toFixed(2), r.refund.toFixed(2), r.discount.toFixed(2), r.netSales.toFixed(2),
        r.accSalesOpen.toFixed(2), r.accSalesClose.toFixed(2), r.companyName, r.zCount,
        String(r.tktResetCount), String(r.accSalesResetCount), r.vatableSales.toFixed(2),
        r.vatAmount.toFixed(2), r.vatExemptSales.toFixed(2), r.zeroRatedSales.toFixed(2),
        r.discountSC.toFixed(2), r.discountPWD.toFixed(2), r.discountStudent.toFixed(2),
        r.totalDeduction.toFixed(2), r.remarks
      ]);
    } else if (activeTab === 'x_reading') {
      headers = ['Date', 'Hour Block', 'Device Name', 'Plate No', 'Company Name', 'Gross Sales', 'Net Sales', 'Txn Count'];
      // Use real hourly data from rides
      generateXReadings().forEach(rec => {
        rows.push([rec.date, rec.hourBlock, rec.deviceName, rec.plateNo, rec.companyName, rec.grossSales.toFixed(2), rec.netSales.toFixed(2), String(rec.txnCount)]);
      });
    } else {
      const type = activeTab === 'sc_book' ? 'SC' : activeTab === 'pwd_book' ? 'PWD' : 'STUDENT';
      const list = getDiscountsBookData(type);
      headers = ['Date', 'Ticket/OR No', 'ID Card No', 'Customer Name', 'Gross Sales', '20% Discount Amount', 'Net Sales', 'Terminal Device', 'Plate No'];
      if (type === 'STUDENT') {
        headers.splice(4, 0, 'School Name');
      }
      rows = list.map(item => {
        const row = [
          item.date, item.ticketNo, item.idNo, item.name, item.grossSales.toFixed(2),
          item.discount.toFixed(2), item.netSales.toFixed(2), item.deviceName, item.plateNo
        ];
        if (type === 'STUDENT') {
          row.splice(4, 0, item.schoolName || '—');
        }
        return row;
      });
    }

    const csvContent = "data:text/csv;charset=utf-8," 
      + [headers.join(','), ...rows.map(e => e.map(val => `"${val.replace(/"/g, '""')}"`).join(','))].join('\n');
    
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handlePrintGrid = () => {
    window.print();
  };

  const resetAllFilters = () => {
    setDatePeriod('yesterday');
    setCustomStartDate('');
    setCustomEndDate('');
    setSelectedDeviceSerial('all');
    setSelectedVehiclePlate('all');
    setSelectedDriverId('all');
    setSearchQuery('');
    setViewMode('summary');
  };

  return (
    <div className="flex flex-col h-full overflow-hidden" style={{background: 'var(--bg-primary)', color: 'var(--text-primary)'}}>
      <div className="flex-1 overflow-y-auto p-6 space-y-5">
      
      {/* ─── PAGE TITLE ──────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-black tracking-wide" style={{color: 'var(--text-primary)'}}>BIR Reports</h1>
          <p className="text-xs mt-0.5" style={{color: 'var(--text-muted)'}}>Bureau of Internal Revenue Compliance Register — Sales Summary &amp; Statutory Books</p>
        </div>
      </div>

      {/* ─── FILTERS HEADER PANEL ────────────────────────────────────────── */}
      <div className="bg-panel border border-borderDark rounded-xl p-5 space-y-4 shadow-sm select-none">
        
        {/* Panel Title & Reset Button */}
        <div className="flex justify-between items-center pb-3 border-b border-borderDark">
          <div className="flex items-center gap-2">
            <Filter className="text-blue-500" size={16} />
            <h3 className="font-bold text-xs tracking-widest uppercase" style={{color: 'var(--text-primary)'}}>Report Filters</h3>
          </div>
          <button 
            onClick={resetAllFilters}
            className="px-3 py-1 border border-red-200 dark:border-red-800/60 text-red-500 hover:bg-red-50 dark:hover:bg-red-950/20 rounded-lg text-[11px] font-semibold transition-all flex items-center gap-1"
          >
            ✕ Reset All
          </button>
        </div>

        {/* Date Filter Selection Row */}
        <div className="space-y-2">
          <span className="text-[10px] font-bold uppercase tracking-widest block" style={{color: 'var(--text-muted)'}}>Date Period</span>
          <div className="flex flex-wrap gap-1.5 items-center">
            {(['today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month', 'all_time', 'custom'] as const).map((period) => (
              <button
                key={period}
                onClick={() => setDatePeriod(period)}
                className={`px-3.5 py-1.5 rounded-lg text-[11px] font-bold transition-all capitalize ${
                  datePeriod === period ? 'shadow-sm' : 'border border-borderDark'
                }`}
                style={{
                  background: datePeriod === period ? '#2563eb' : 'var(--bg-card)',
                  color: datePeriod === period ? '#ffffff' : 'var(--text-secondary)',
                }}
              >
                {period.replace('_', ' ')}
              </button>
            ))}

            {datePeriod === 'custom' && (
              <div className="flex items-center gap-2 ml-2 animate-in fade-in duration-150">
                <input 
                  type="date"
                  value={customStartDate}
                  onChange={(e) => setCustomStartDate(e.target.value)}
                  className="px-3 py-1.5 border border-borderDark rounded-lg text-xs outline-none focus:border-accentOrange"
                  style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
                />
                <span className="text-textFaint text-xs">—</span>
                <input 
                  type="date"
                  value={customEndDate}
                  onChange={(e) => setCustomEndDate(e.target.value)}
                  className="px-3 py-1.5 border border-borderDark rounded-lg text-xs outline-none focus:border-accentOrange"
                  style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
                />
              </div>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          
          <div className="space-y-1">
            <span className="text-[10px] font-semibold uppercase tracking-widest flex items-center gap-1" style={{color: 'var(--text-muted)'}}>
              <Smartphone size={10} />
              Device Terminal
            </span>
            <select
              value={selectedDeviceSerial}
              onChange={(e) => setSelectedDeviceSerial(e.target.value)}
              className="w-full px-3 py-2 bg-cardColor border border-borderDark rounded-lg text-xs outline-none focus:border-blue-500" style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
            >
              <option value="all">All Devices</option>
              {devices.map(d => (
                <option key={d.serialNo} value={d.serialNo}>{d.serialNo} ({d.plateNo})</option>
              ))}
            </select>
          </div>

          <div className="space-y-1">
            <span className="text-[10px] font-semibold uppercase tracking-widest flex items-center gap-1" style={{color: 'var(--text-muted)'}}>
              <Bus size={10} />
              Vehicle (Fleet)
            </span>
            <select
              value={selectedVehiclePlate}
              onChange={(e) => setSelectedVehiclePlate(e.target.value)}
              className="w-full px-3 py-2 bg-cardColor border border-borderDark rounded-lg text-xs outline-none focus:border-blue-500" style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
            >
              <option value="all">All Vehicles</option>
              {devices.map(d => (
                <option key={d.serialNo} value={d.plateNo}>{d.plateNo}</option>
              ))}
            </select>
          </div>

          <div className="space-y-1">
            <span className="text-[10px] font-semibold uppercase tracking-widest flex items-center gap-1" style={{color: 'var(--text-muted)'}}>
              <User size={10} />
              Driver
            </span>
            <select
              value={selectedDriverId}
              onChange={(e) => setSelectedDriverId(e.target.value)}
              className="w-full px-3 py-2 bg-cardColor border border-borderDark rounded-lg text-xs outline-none focus:border-blue-500" style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
            >
              <option value="all">All Drivers</option>
              {users.filter(u => u.role === 'driver' || u.role === 'device').map(u => (
                <option key={u.id} value={u.id}>{u.name || u.email}</option>
              ))}
            </select>
          </div>

        </div>

      </div>

      <div className="bg-panel border border-borderDark rounded-xl shadow-sm">
        <div className="flex items-center gap-1 px-3 pt-3 pb-0 overflow-x-auto">
          {([
            { id: 'summary', label: 'Summary Sales', icon: FileText },
            { id: 'x_reading', label: 'X-Reading', icon: Smartphone },
            { id: 'sc_book', label: 'Senior Citizens Book', icon: User },
            { id: 'students_book', label: 'Students Book', icon: BookOpen },
            { id: 'pwd_book', label: 'PWD Book', icon: Accessibility },
            { id: 'other_discounts', label: 'Other Discounts', icon: Tag },
          ] as const).map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              onClick={() => setActiveTab(id)}
              className={`flex items-center gap-1.5 px-4 py-2 text-[11px] font-bold whitespace-nowrap border-b-2 transition-all ${
                activeTab === id
                  ? 'border-blue-500 text-white'
                  : 'border-transparent text-textFaint hover:text-white hover:border-borderDark'
              }`}
            >
              <Icon size={13} />
              {label}
            </button>
          ))}
        </div>

        <div className="border-b border-borderDark mx-3" />

        <div className="flex items-center justify-between gap-3 px-4 py-3">
          <div className="flex items-center gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-textFaint" size={13} />
              <input
                type="text"
                placeholder="Search serial, plate, dispatch..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-8 pr-4 py-1.5 border border-borderDark rounded-lg text-xs w-60 outline-none focus:border-blue-500 placeholder-textFaint"
                style={{background: 'var(--bg-card)', color: 'var(--text-primary)'}}
              />
            </div>

            {activeTab === 'summary' && (
              <div className="flex items-center border border-borderDark rounded-lg p-0.5" style={{background: 'var(--bg-card)'}}>
                <button
                  onClick={() => setViewMode('summary')}
                  className={`px-3 py-1 rounded-md text-[11px] font-bold transition-all ${
                    viewMode === 'summary' ? 'shadow-sm' : ''
                  }`}
                  style={{
                    background: viewMode === 'summary' ? '#2563eb' : 'transparent',
                    color: viewMode === 'summary' ? '#ffffff' : 'var(--text-secondary)',
                  }}
                >
                  Overview
                </button>
                <button
                  onClick={() => setViewMode('full')}
                  className={`px-3 py-1 rounded-md text-[11px] font-bold transition-all ${
                    viewMode === 'full' ? 'shadow-sm' : ''
                  }`}
                  style={{
                    background: viewMode === 'full' ? '#2563eb' : 'transparent',
                    color: viewMode === 'full' ? '#ffffff' : 'var(--text-secondary)',
                  }}
                >
                  Full Z-Book
                </button>
              </div>
            )}
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleExport}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-[11px] font-bold rounded-lg transition-all shadow-sm"
            >
              <Download size={13} />
              Export Selected Book
            </button>
            <button
              onClick={handlePrintGrid}
              className="p-2 border border-borderDark text-textFaint hover:text-white hover:bg-borderDark/40 rounded-lg transition-all"
              title="Print"
            >
              <Printer size={14} />
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 select-none">
        
        <div className="bg-panel border border-borderDark rounded-xl p-4 flex flex-col justify-between h-24 shadow-sm">
          <span className="text-[10px] font-bold text-textFaint uppercase tracking-widest">No. of Transactions</span>
          <div>
            <span className="text-2xl font-black text-blue-600 dark:text-blue-400">{totalTxn}</span>
            <span className="text-[9px] font-medium text-textFaint block mt-0.5">TOTAL TRANSACTIONS</span>
          </div>
        </div>

        <div className="bg-panel border border-borderDark rounded-xl p-4 flex flex-col justify-between h-24 shadow-sm">
          <span className="text-[10px] font-bold text-textFaint uppercase tracking-widest">Total Gross Sales</span>
          <div>
            <span className="text-xl font-black text-blue-600 dark:text-blue-400">₱{totalGross.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            <span className="text-[9px] font-medium text-textFaint block mt-0.5">COMMON CARRIER & CARGO</span>
          </div>
        </div>

        <div className="bg-panel border border-borderDark rounded-xl p-4 flex flex-col justify-between h-24 shadow-sm">
          <span className="text-[10px] font-bold text-textFaint uppercase tracking-widest">Total Refund</span>
          <div>
            <span className="text-xl font-black text-red-500 dark:text-red-400">₱{totalRefund.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            <span className="text-[9px] font-medium text-textFaint block mt-0.5">VOID & REFUNDED FARES</span>
          </div>
        </div>

        <div className="bg-panel border border-borderDark rounded-xl p-4 flex flex-col justify-between h-24 shadow-sm">
          <span className="text-[10px] font-bold text-textFaint uppercase tracking-widest">Total Discount</span>
          <div>
            <span className="text-xl font-black text-orange-500 dark:text-orange-400">₱{totalDiscount.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            <span className="text-[9px] font-medium text-textFaint block mt-0.5">TOTAL DISCOUNTS GRANTED</span>
          </div>
        </div>

        <div className="bg-panel border-2 border-green-500/30 rounded-xl p-4 flex flex-col justify-between h-24 shadow-sm">
          <span className="text-[10px] font-bold text-textFaint uppercase tracking-widest">Total Net Sales</span>
          <div>
            <span className="text-xl font-black text-green-600 dark:text-green-400">₱{totalNet.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            <span className="text-[9px] font-medium text-textFaint block mt-0.5">GROSS LESS DEDUCTIONS</span>
          </div>
        </div>

      </div>

      <div className="bg-panel border border-borderDark rounded-xl overflow-hidden shadow-sm flex-1 flex flex-col min-h-[400px]">
        
        <div className="flex-1 overflow-x-auto overflow-y-auto" style={{maxHeight: 'calc(100vh - 480px)', minHeight: '320px', background: 'var(--bg-panel)'}}>

          {loading && (
            <div className="flex items-center justify-center h-40">
              <div className="text-textFaint text-sm animate-pulse">Loading data from Firestore…</div>
            </div>
          )}

          {!loading && activeTab === 'summary' && viewMode === 'summary' && (
            <table className="w-full border-collapse border border-borderDark select-none text-[11px] font-bold" style={{background: 'var(--bg-panel)', color: 'var(--text-primary)'}}>
              <thead>
                <tr className="text-white text-center text-[10px] h-12 border-b border-borderDark font-black" style={{background: 'var(--accent-primary)'}}>
                  <th className="border border-borderDark px-4 py-3 w-24">DATE</th>
                  <th className="border border-borderDark px-4 py-3 w-24">DISPATCH NO.</th>
                  <th className="border border-borderDark px-4 py-3 w-28">DEVICE NAME</th>
                  <th className="border border-borderDark px-4 py-3 w-32">VEHICLE / PLATE NO.</th>
                  <th className="border border-borderDark px-4 py-3 w-20">NO. OF TXN</th>
                  <th className="border border-borderDark px-4 py-3 w-28">GROSS SALES</th>
                  <th className="border border-borderDark px-4 py-3 w-24">REFUND</th>
                  <th className="border border-borderDark px-4 py-3 w-24">DISCOUNT</th>
                  <th className="border border-borderDark px-4 py-3 w-28" style={{background: 'var(--accent-success)'}}>NET SALES</th>
                  <th className="border border-borderDark px-4 py-3">REMARKS</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-center">
                {filteredZReadings.length === 0 ? (
                  <tr>
                    <td colSpan={10} className="py-16 text-center text-textFaint" style={{background: 'var(--bg-panel)'}}>
                      No Z-Reading records found for the selected period.
                    </td>
                  </tr>
                ) : (
                  filteredZReadings.map((r, index) => (
                    <tr key={r.id || index} className="hover:bg-cardColor transition-colors h-11" style={{background: 'var(--bg-panel)'}}>
                      <td className="border border-borderDark px-4 py-2" style={{color: 'var(--text-secondary)'}}>{r.date}</td>
                      <td className="border border-borderDark px-4 py-2 font-mono text-blue-500">{r.dispatchNo}</td>
                      <td className="border border-borderDark px-4 py-2 font-mono" style={{color: 'var(--text-primary)'}}>{r.deviceName}</td>
                      <td className="border border-borderDark px-4 py-2 font-bold" style={{color: 'var(--text-primary)'}}>{r.plateNo}</td>
                      <td className="border border-borderDark px-4 py-2 font-bold" style={{color: 'var(--text-primary)'}}>{r.noOfTxn}</td>
                      <td className="border border-borderDark px-4 py-2 text-emerald-500 text-right font-bold font-mono">₱{r.grossSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 py-2 text-red-500 text-right font-bold font-mono">₱{r.refund.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 py-2 text-amber-500 text-right font-bold font-mono">₱{r.discount.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 py-2 text-emerald-500 text-right font-bold font-mono" style={{background: 'rgba(16,185,129,0.06)'}}>₱{r.netSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 py-2 text-left" style={{color: 'var(--text-secondary)'}}>{r.remarks}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {!loading && activeTab === 'summary' && viewMode === 'full' && (
            <table className="min-w-[4500px] border-collapse border border-borderDark select-none table-fixed text-[11px] font-bold" style={{background: 'var(--bg-panel)', color: 'var(--text-primary)'}}>
              <thead>
                <tr className="text-white text-center font-black">
                  <th colSpan={10} className="bg-slate-600 border border-borderDark py-2 tracking-wide text-[10px]">VEHICLE & OPERATIONAL IDENTIFICATION</th>
                  <th colSpan={4} className="bg-emerald-700 border border-borderDark py-2 tracking-wide text-[10px]">TRANSACTIONAL SALES OUTCOMES</th>
                  <th colSpan={2} className="bg-blue-700 border border-borderDark py-2 tracking-wide text-[10px]">ACCUMULATED BALANCES</th>
                  <th colSpan={4} className="bg-purple-700 border border-borderDark py-2 tracking-wide text-[10px]">TERMINAL AUDITING</th>
                  <th colSpan={4} className="bg-yellow-600 border border-borderDark py-2 tracking-wide text-[10px]">VALUE ADDED TAX BREAKDOWN</th>
                  <th colSpan={4} className="bg-orange-600 border border-borderDark py-2 tracking-wide text-[10px]">STATUTORY CUSTOMER DISCOUNTS</th>
                  <th colSpan={7} className="bg-orange-500 border border-borderDark py-2 tracking-wide text-[10px]">DEDUCTIONS</th>
                  <th colSpan={7} className="bg-lime-700 border border-borderDark py-2 tracking-wide text-[10px]">ADJUSTMENT ON VAT</th>
                  <th colSpan={1} rowSpan={3} className="bg-slate-700 border border-borderDark py-2 tracking-wide text-[10px] align-middle">VAT PAYABLE</th>
                  <th colSpan={1} rowSpan={3} className="bg-slate-700 border border-borderDark py-2 tracking-wide text-[10px] align-middle">SALES OVERFLOW</th>
                  <th colSpan={1} rowSpan={3} className="bg-slate-700 border border-borderDark py-2 tracking-wide text-[10px] align-middle">REMARKS</th>
                </tr>
                <tr className="bg-cardColor text-white text-center text-[10px] h-12 border-b border-borderDark">
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">DATE</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">DISPATCH NO.</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">DEVICE NAME</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-36">Z-READING DATE & TIME</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">PLATE / BODY NO.</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">BEGINNING SI/OR NO.</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">ENDING SI/OR NO.</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">NO. OF TXN</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">START REFUND TICKET #</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">END REFUND TICKET #</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">GROSS SALES</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">REFUND</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">DISCOUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">NET SALES</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-32">ACC. SALES OPEN</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-32">ACC. SALES CLOSE</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">COMPANY NAME</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">Z-COUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">TKT # RESET COUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">ACC SALES RESET COUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">VATABLE SALES</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">VAT AMOUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">VAT-EXEMPT SALES</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">ZERO-RATED SALES</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">SC</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">PWD</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">STUDENT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">OTHERS</th>
                  <th colSpan={4} className="border border-borderDark px-2">DISCOUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">REFUNDS</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">VOIDS</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">TOTAL DEDUCTION</th>
                  <th colSpan={4} className="border border-borderDark px-2">DISCOUNT</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-24">VAT ON REFUNDS</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-20">OTHERS</th>
                  <th rowSpan={2} className="border border-borderDark px-2 w-28">TOTAL VAT ADJUSTMENT</th>
                </tr>
                <tr className="bg-cardColor text-white text-center text-[9px] h-10 border-b border-borderDark font-bold">
                  <th className="border border-borderDark px-2 w-20">SC</th>
                  <th className="border border-borderDark px-2 w-20">PWD</th>
                  <th className="border border-borderDark px-2 w-20">STUDENT</th>
                  <th className="border border-borderDark px-2 w-20">OTHERS</th>
                  <th className="border border-borderDark px-2 w-20">SC</th>
                  <th className="border border-borderDark px-2 w-20">PWD</th>
                  <th className="border border-borderDark px-2 w-20">STUDENT</th>
                  <th className="border border-borderDark px-2 w-20">OTHERS</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-center">
                {filteredZReadings.length === 0 ? (
                  <tr>
                    <td colSpan={44} className="py-16 text-center text-textFaint" style={{background: 'var(--bg-panel)'}}>
                      No Z-Reading records found for the selected period.
                    </td>
                  </tr>
                ) : (
                  filteredZReadings.map((r, index) => (
                    <tr key={r.id || index} className="hover:bg-cardColor transition-colors h-11" style={{background: 'var(--bg-panel)'}}>
                      <td className="border border-borderDark px-2" style={{color:'var(--text-secondary)'}}>{r.date}</td>
                      <td className="border border-borderDark px-2 font-mono text-blue-500">{r.dispatchNo}</td>
                      <td className="border border-borderDark px-2 font-mono" style={{color:'var(--text-primary)'}}>{r.deviceName}</td>
                      <td className="border border-borderDark px-2 text-[10px] font-mono text-purple-500">{r.zReadingDateTime}</td>
                      <td className="border border-borderDark px-2 font-bold" style={{color:'var(--text-primary)'}}>{r.plateNo}</td>
                      <td className="border border-borderDark px-2 font-mono text-textFaint">{r.beginningSiOrNo}</td>
                      <td className="border border-borderDark px-2 font-mono text-textFaint">{r.endingSiOrNo}</td>
                      <td className="border border-borderDark px-2 font-bold" style={{color:'var(--text-primary)'}}>{r.noOfTxn}</td>
                      <td className="border border-borderDark px-2 font-mono text-textFaint">{r.startRefundTicketNo}</td>
                      <td className="border border-borderDark px-2 font-mono text-textFaint">{r.endRefundTicketNo}</td>
                      <td className="border border-borderDark px-2 text-emerald-500 text-right font-bold font-mono">₱{r.grossSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-red-500 text-right font-bold font-mono">₱{r.refund.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-amber-500 text-right font-bold font-mono">₱{r.discount.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-emerald-500 text-right font-bold font-mono" style={{background:'rgba(16,185,129,0.06)'}}>₱{r.netSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-blue-500 text-right font-bold font-mono" style={{background:'rgba(59,130,246,0.06)'}}>₱{r.accSalesOpen.toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
                      <td className="border border-borderDark px-2 text-blue-500 text-right font-bold font-mono" style={{background:'rgba(59,130,246,0.06)'}}>₱{r.accSalesClose.toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
                      <td className="border border-borderDark px-2 font-bold text-left" style={{color:'var(--text-primary)'}}>{r.companyName}</td>
                      <td className="border border-borderDark px-2 font-bold text-purple-500">{r.zCount}</td>
                      <td className="border border-borderDark px-2 text-amber-500">{r.tktResetCount}</td>
                      <td className="border border-borderDark px-2 text-red-500">{r.accSalesResetCount}</td>
                      <td className="border border-borderDark px-2 text-right font-mono" style={{color:'var(--text-primary)'}}>₱{r.vatableSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-red-500">₱{r.vatAmount.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-textFaint">₱{r.vatExemptSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">₱{r.discountSC.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">₱{r.discountPWD.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">₱{r.discountStudent.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">{r.discountSC > 0 ? `₱${r.discountSC.toFixed(2)}` : '—'}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">{r.discountPWD > 0 ? `₱${r.discountPWD.toFixed(2)}` : '—'}</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-amber-500">{r.discountStudent > 0 ? `₱${r.discountStudent.toFixed(2)}` : '—'}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-right font-mono text-red-500">{r.refunds > 0 ? `₱${r.refunds.toFixed(2)}` : '—'}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-right font-bold font-mono text-amber-500" style={{background:'rgba(245,158,11,0.08)'}}>₱{r.totalDeduction.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-right font-bold font-mono text-emerald-500" style={{background:'rgba(16,185,129,0.08)'}}>₱{r.vatAdjTotal.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-right font-bold font-mono text-red-500" style={{background:'rgba(239,68,68,0.08)'}}>₱{r.vatPayable.toFixed(2)}</td>
                      <td className="border border-borderDark px-2 text-center text-textFaint">—</td>
                      <td className="border border-borderDark px-2 text-left" style={{color:'var(--text-secondary)'}}>{r.remarks}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {!loading && activeTab === 'x_reading' && (
            <table className="w-full border-collapse border border-borderDark select-none text-[11px] font-bold" style={{background:'var(--bg-panel)', color:'var(--text-primary)'}}>
              <thead>
                <tr className="text-white text-center font-black" style={{background:'#1d4ed8'}}>
                  <th className="border border-borderDark p-3">DATE</th>
                  <th className="border border-borderDark p-3">HOUR BLOCK</th>
                  <th className="border border-borderDark p-3">DEVICE NAME</th>
                  <th className="border border-borderDark p-3">PLATE NO.</th>
                  <th className="border border-borderDark p-3">COMPANY NAME</th>
                  <th className="border border-borderDark p-3">GROSS SALES</th>
                  <th className="border border-borderDark p-3">NET SALES</th>
                  <th className="border border-borderDark p-3">TXN COUNT</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-center">
                {generateXReadings().length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-16 text-center text-textFaint" style={{background:'var(--bg-panel)'}}>
                      No X-Reading data for the selected period.
                    </td>
                  </tr>
                ) : (
                  generateXReadings().map((row, index) => (
                    <tr key={index} className="hover:bg-cardColor transition-colors h-11" style={{background:'var(--bg-panel)'}}>
                      <td className="border border-borderDark px-4" style={{color:'var(--text-secondary)'}}>{row.date}</td>
                      <td className="border border-borderDark px-4 text-blue-500 font-mono">{row.hourBlock}</td>
                      <td className="border border-borderDark px-4 font-mono" style={{color:'var(--text-primary)'}}>{row.deviceName}</td>
                      <td className="border border-borderDark px-4 font-bold" style={{color:'var(--text-primary)'}}>{row.plateNo}</td>
                      <td className="border border-borderDark px-4 text-left" style={{color:'var(--text-secondary)'}}>{row.companyName}</td>
                      <td className="border border-borderDark px-4 text-right font-mono text-emerald-500">₱{row.grossSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 text-right font-mono text-emerald-500">₱{row.netSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 font-bold" style={{color:'var(--text-primary)'}}>{row.txnCount}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {!loading && ['sc_book', 'pwd_book', 'students_book'].includes(activeTab) && (
            <table className="w-full border-collapse border border-borderDark select-none text-[11px] font-bold" style={{background:'var(--bg-panel)', color:'var(--text-primary)'}}>
              <thead>
                <tr className="text-white text-center font-black" style={{background:'#92400e'}}>
                  <th className="border border-borderDark p-3">DATE</th>
                  <th className="border border-borderDark p-3">TICKET/OR NO.</th>
                  <th className="border border-borderDark p-3">
                    {activeTab === 'sc_book' ? 'OSCA ID NO.' : activeTab === 'pwd_book' ? 'PWD ID NO.' : 'STUDENT ID NO.'}
                  </th>
                  <th className="border border-borderDark p-3">PASSENGER NAME</th>
                  {activeTab === 'students_book' && <th className="border border-borderDark p-3">SCHOOL NAME</th>}
                  <th className="border border-borderDark p-3">GROSS FARE</th>
                  <th className="border border-borderDark p-3">20% DISCOUNT</th>
                  <th className="border border-borderDark p-3">NET FARE</th>
                  <th className="border border-borderDark p-3">MDT TERMINAL</th>
                  <th className="border border-borderDark p-3">PLATE NO.</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-center">
                {getDiscountsBookData(activeTab === 'sc_book' ? 'SC' : activeTab === 'pwd_book' ? 'PWD' : 'STUDENT').length === 0 ? (
                  <tr>
                    <td colSpan={activeTab === 'students_book' ? 10 : 9} className="py-16 text-center text-textFaint" style={{background:'var(--bg-panel)'}}>
                      No {activeTab === 'sc_book' ? 'Senior Citizen' : activeTab === 'pwd_book' ? 'PWD' : 'Student'} discount transactions found for the selected period.
                    </td>
                  </tr>
                ) : (
                  getDiscountsBookData(activeTab === 'sc_book' ? 'SC' : activeTab === 'pwd_book' ? 'PWD' : 'STUDENT').map((item, idx) => (
                    <tr key={idx} className="hover:bg-cardColor transition-colors h-11" style={{background:'var(--bg-panel)'}}>
                      <td className="border border-borderDark px-4" style={{color:'var(--text-secondary)'}}>{item.date}</td>
                      <td className="border border-borderDark px-4 font-mono text-blue-500">{item.ticketNo}</td>
                      <td className="border border-borderDark px-4 font-mono text-purple-500">{item.idNo}</td>
                      <td className="border border-borderDark px-4 text-left font-bold" style={{color:'var(--text-primary)'}}>{item.name}</td>
                      {activeTab === 'students_book' && <td className="border border-borderDark px-4 text-left text-textFaint">{item.schoolName}</td>}
                      <td className="border border-borderDark px-4 text-right font-mono text-emerald-500">₱{item.grossSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 text-right font-mono text-amber-500">₱{item.discount.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 text-right font-mono text-emerald-500">₱{item.netSales.toFixed(2)}</td>
                      <td className="border border-borderDark px-4 font-mono" style={{color:'var(--text-primary)'}}>{item.deviceName}</td>
                      <td className="border border-borderDark px-4 font-bold" style={{color:'var(--text-primary)'}}>{item.plateNo}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {!loading && activeTab === 'other_discounts' && (
            <table className="w-full border-collapse border border-borderDark select-none text-[11px] font-bold" style={{background:'var(--bg-panel)', color:'var(--text-primary)'}}>
              <thead>
                <tr className="text-white text-center font-black" style={{background:'#334155'}}>
                  <th className="border border-borderDark p-3">DATE</th>
                  <th className="border border-borderDark p-3">TICKET/OR NO.</th>
                  <th className="border border-borderDark p-3">DISCOUNT TYPE</th>
                  <th className="border border-borderDark p-3">GROSS FARE</th>
                  <th className="border border-borderDark p-3">DISCOUNT AMOUNT</th>
                  <th className="border border-borderDark p-3">NET FARE</th>
                  <th className="border border-borderDark p-3">MDT TERMINAL</th>
                  <th className="border border-borderDark p-3">PLATE NO.</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borderDark text-center">
                <tr style={{background:'var(--bg-panel)'}}>
                  <td colSpan={8} className="py-16 text-center text-textFaint">
                    No promotional / other discount transactions found for the selected period.
                  </td>
                </tr>
              </tbody>
            </table>
          )}

        </div>
      </div>

      </div>{/* end inner scroll */}
    </div>
  );
};
