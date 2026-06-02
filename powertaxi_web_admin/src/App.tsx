import { useState, useEffect } from 'react';
import { FareSettings } from './components/FareSettings';
import { CompaniesManagement } from './components/CompaniesManagement';
import { DevicesManagement } from './components/DevicesManagement';
import { UserManagement } from './components/UserManagement';
import { DispatchMonitor } from './components/DispatchMonitor';
import { TripRecords } from './components/TripRecords';
import { Reports } from './components/Reports';
import { TaxiMeter } from './components/TaxiMeter';
import { Login } from './components/Login';
import { subscribeToCompanies } from './services/firebase';
import type { Company } from './services/firebase';
import { 
  Compass, 
  Tablet, 
  Building, 
  Users, 
  Calculator, 
  FileSpreadsheet, 
  BarChart, 
  Bolt,
  LogOut,
  ChevronDown,
  User,
  AlertTriangle,
  MonitorSmartphone
} from 'lucide-react';

const SLUG_TO_NAV: Record<string, string> = {
  'dispatch': 'Dispatch',
  'devices': 'Devices',
  'companies': 'Companies',
  'users': 'Users',
  'fare-settings': 'Fare Settings',
  'trip-records': 'Trip Records',
  'reports': 'Reports',
  'meter-simulator': 'Meter Simulator'
};

const NAV_TO_SLUG: Record<string, string> = {
  'Dispatch': 'dispatch',
  'Devices': 'devices',
  'Companies': 'companies',
  'Users': 'users',
  'Fare Settings': 'fare-settings',
  'Trip Records': 'trip-records',
  'Reports': 'reports',
  'Meter Simulator': 'meter-simulator'
};

export default function App() {
  const [currentUser, setCurrentUser] = useState<any>(() => {
    const saved = localStorage.getItem('power_taxi_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [selectedNav, setSelectedNav] = useState(() => {
    const hash = window.location.hash.replace('#/', '');
    return SLUG_TO_NAV[hash] || 'Fare Settings';
  });
  const [companies, setCompanies] = useState<Company[]>([]);
  const [selectedCompanyId, setSelectedCompanyId] = useState<string | null>(null);
  const [selectedCompanyName, setSelectedCompanyName] = useState<string>('All Companies');
  const [companyDropdownOpen, setCompanyDropdownOpen] = useState(false);
  const [profileDropdownOpen, setProfileDropdownOpen] = useState(false);

  const handleLogout = () => {
    setCurrentUser(null);
    localStorage.removeItem('power_taxi_user');
    setProfileDropdownOpen(false);
  };

  // Nav menu items
  const navItems = [
    { label: 'Meter Simulator', icon: MonitorSmartphone },
    { label: 'Dispatch', icon: Compass },
    { label: 'Devices', icon: Tablet },
    { label: 'Companies', icon: Building },
    { label: 'Users', icon: Users },
    { label: 'Fare Settings', icon: Calculator },
    { label: 'Trip Records', icon: FileSpreadsheet },
    { label: 'Reports', icon: BarChart },
  ];

  // Sync selected navigation tab to the browser URL hash
  useEffect(() => {
    if (currentUser) {
      const slug = NAV_TO_SLUG[selectedNav];
      if (slug) {
        window.location.hash = `#/${slug}`;
      }
    } else {
      window.location.hash = '';
    }
  }, [selectedNav, currentUser]);

  // Listen to browser backward/forward history changes
  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.replace('#/', '');
      const nav = SLUG_TO_NAV[hash];
      if (nav) {
        setSelectedNav(nav);
      }
    };

    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  // Subscribe to companies to populate sidebar filter
  useEffect(() => {
    const unsubscribe = subscribeToCompanies((list) => {
      setCompanies(list);
    });
    return () => unsubscribe();
  }, []);

  const handleSelectCompany = (company: Company | null) => {
    if (company) {
      setSelectedCompanyId(company.id);
      setSelectedCompanyName(company.name);
    } else {
      setSelectedCompanyId(null);
      setSelectedCompanyName('All Companies');
    }
    setCompanyDropdownOpen(false);
  };

  const renderContent = () => {
    switch (selectedNav) {
      case 'Meter Simulator':
        return <TaxiMeter />;
      case 'Dispatch':
        return (
          <DispatchMonitor 
            selectedCompanyId={selectedCompanyId} 
            selectedCompanyName={selectedCompanyName} 
          />
        );
      case 'Trip Records':
        return <TripRecords selectedCompanyId={selectedCompanyId} />;
      case 'Reports':
        return <Reports selectedCompanyId={selectedCompanyId} />;
      case 'Users':
        return <UserManagement selectedCompanyId={selectedCompanyId} />;
      case 'Devices':
        return <DevicesManagement selectedCompanyId={selectedCompanyId} />;
      case 'Companies':
        return <CompaniesManagement />;
      case 'Fare Settings':
        return (
          <FareSettings 
            selectedCompanyId={selectedCompanyId} 
            onSelectCompany={(id) => {
              setSelectedCompanyId(id);
              if (id === null) {
                setSelectedCompanyName('All Companies');
              } else {
                const comp = companies.find(c => c.id === id);
                if (comp) setSelectedCompanyName(comp.name);
              }
            }} 
          />
        );
      default:
        return (
          <div className="flex-1 flex flex-col items-center justify-center space-y-4">
            <div className="p-4 bg-amber-500/10 text-amber-500 rounded-full border border-amber-500/20">
              <AlertTriangle size={32} />
            </div>
            <h3 className="text-base font-bold text-white">Tab Under Development</h3>
            <p className="text-xs text-textFaint text-center max-w-sm leading-relaxed">
              The &ldquo;{selectedNav}&rdquo; panel is currently active in the primary Flutter panel and is queued for migration to React in the next release.
            </p>
          </div>
        );
    }
  };

  if (!currentUser) {
    return <Login onLoginSuccess={(user) => setCurrentUser(user)} />;
  }

  return (
    <div className="flex h-screen bg-bg text-white overflow-hidden font-sans">
      
      {/* ─── SIDEBAR ────────────────────────────────────────────────────────── */}
      <aside className="w-60 bg-[#0D1017] border-r border-borderDark flex flex-col justify-between shrink-0">
        <div className="flex flex-col min-h-0">
          
          {/* Logo Header */}
          <div className="h-16 flex items-center gap-3 px-6 border-b border-borderDark shrink-0">
            <div className="w-7 h-7 bg-accentOrange rounded-lg flex items-center justify-center text-black shadow-lg shadow-accentOrange/25">
              <Bolt size={18} strokeWidth={2.5} />
            </div>
            <span className="font-black text-sm tracking-wider uppercase text-white">
              PowerTaxi
            </span>
          </div>

          {/* Company Dropdown Filter */}
          <div className="p-4 shrink-0 relative">
            <button 
              onClick={() => setCompanyDropdownOpen(!companyDropdownOpen)}
              className="w-full flex items-center justify-between gap-3 px-3 py-2 bg-borderDark hover:bg-borderDark/80 rounded-lg border border-borderDark text-left transition-colors"
            >
              <div className="flex items-center gap-2 overflow-hidden">
                <Building className="text-textFaint shrink-0" size={13} />
                <span className="text-[11px] font-bold text-white/80 truncate">
                  {selectedCompanyName}
                </span>
              </div>
              <ChevronDown className="text-textFaint shrink-0" size={13} />
            </button>

            {/* Dropdown Menu */}
            {companyDropdownOpen && (
              <div className="absolute left-4 right-4 mt-2 bg-[#1A1E26] border border-borderDark rounded-lg shadow-2xl z-50 py-1 overflow-y-auto max-h-56">
                <button 
                  onClick={() => handleSelectCompany(null)}
                  className="w-full text-left px-4 py-2 hover:bg-borderDark/50 text-xs font-semibold text-white/80 transition-colors"
                >
                  All Companies
                </button>
                <div className="border-t border-borderDark my-1"></div>
                {companies.map((c) => (
                  <button 
                    key={c.id}
                    onClick={() => handleSelectCompany(c)}
                    className="w-full text-left px-4 py-2 hover:bg-borderDark/50 text-xs text-white/70 transition-colors truncate"
                  >
                    {c.name}
                  </button>
                ))}
              </div>
            )}
          </div>

          <div className="border-t border-borderDark my-1 shrink-0"></div>

          {/* Navigation Links */}
          <nav className="flex-1 overflow-y-auto px-2 py-4 space-y-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isSelected = selectedNav === item.label;
              return (
                <button
                  key={item.label}
                  onClick={() => {
                    setSelectedNav(item.label);
                    // Close overlays
                    setCompanyDropdownOpen(false);
                    setProfileDropdownOpen(false);
                  }}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left transition-all ${
                    isSelected 
                      ? 'bg-accentOrange/10 text-white border border-accentOrange/25 shadow-sm' 
                      : 'text-textFaint hover:text-white/80 hover:bg-borderDark/20'
                  }`}
                >
                  <Icon size={16} className={isSelected ? 'text-accentOrange' : 'text-textFaint'} />
                  <span className="text-xs font-semibold tracking-wide">
                    {item.label}
                  </span>
                </button>
              );
            })}
          </nav>
        </div>

        {/* Footer Logout */}
        <div className="p-4 border-t border-borderDark shrink-0">
          <button 
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left text-red-400 hover:text-red-300 hover:bg-red-950/20 transition-colors"
          >
            <LogOut size={16} />
            <span className="text-xs font-bold tracking-wide">Logout</span>
          </button>
        </div>
      </aside>

      {/* ─── MAIN APP AREA ─────────────────────────────────────────────────── */}
      <main className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
        
        {/* Top Navbar */}
        <header className="h-16 bg-panel border-b border-borderDark flex items-center justify-between px-8 shrink-0">
          <h2 className="text-sm font-black tracking-wider text-white uppercase">
            {selectedNav}
          </h2>

          {/* User Profile */}
          <div className="relative">
            <button 
              onClick={() => setProfileDropdownOpen(!profileDropdownOpen)}
              className="flex items-center gap-3 hover:opacity-80 transition-opacity"
            >
              <div className="w-8 h-8 rounded-full bg-borderDark border border-borderDark flex items-center justify-center text-white/80">
                <User size={16} />
              </div>
              <div className="text-left hidden sm:block">
                <p className="text-xs font-bold text-white">{currentUser?.name || currentUser?.email || 'System User'}</p>
                <p className="text-[10px] text-textFaint uppercase tracking-wider font-semibold">{(currentUser?.role || 'operator')}</p>
              </div>
            </button>

            {/* Profile Dropdown Menu */}
            {profileDropdownOpen && (
              <div className="absolute right-0 mt-2 w-48 bg-[#1A1E26] border border-borderDark rounded-lg shadow-2xl z-50 py-1">
                <div className="px-4 py-2 border-b border-borderDark/60 text-[10px] text-textFaint truncate">
                  Logged in as:
                  <span className="block font-bold text-white/90 truncate">{currentUser?.email}</span>
                </div>
                <button 
                  onClick={handleLogout}
                  className="w-full text-left px-4 py-2 hover:bg-borderDark/50 text-xs text-red-400 hover:text-red-300 transition-colors"
                >
                  Logout
                </button>
              </div>
            )}
          </div>
        </header>

        {/* Content Tab Renderer */}
        <div className="flex-1 min-h-0 bg-bg">
          {renderContent()}
        </div>

      </main>

    </div>
  );
}
