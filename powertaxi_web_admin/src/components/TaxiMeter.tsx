import { useState, useEffect } from 'react';


type MeterStatus = 'vacant' | 'hired' | 'stopped';

export function TaxiMeter() {
  const [status, setStatus] = useState<MeterStatus>('vacant');
  const [showMemory, setShowMemory] = useState(false);
  const [time, setTime] = useState(new Date());
  
  const rawFare = status === 'vacant' ? 0.00 : (status === 'hired' ? 124.47 : 850.12);
  // Round to nearest 0.25
  const fare = Math.round(rawFare * 4) / 4;
  
  const distance = status === 'vacant' ? 0.0 : 8.1;
  const elapsed = status === 'vacant' ? '00:00' : '25:00';

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const handleVacant = () => setStatus('vacant');
  const handleHired = () => setStatus('hired');
  const handleStop = () => setStatus('stopped');

  return (
    <div className="h-full bg-[#0B0E14] text-white p-4 font-sans relative flex flex-col">
      {/* Top Bar */}
      <div className="flex justify-between items-center mb-4 px-2">
        <div className="text-sm font-bold tracking-widest text-white/70">
          DIGITAL TAXI METER <span className="ml-4 text-white/40">SIMULATOR</span>
        </div>
        <div className="flex items-center gap-6">
          <div className="text-[10px] font-black text-green-500 tracking-wider">SHIFT: ACTIVE</div>
          <div className="text-[10px] font-black text-blue-400 tracking-wider">READY</div>
          <div className="text-[12px] font-bold">{time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex gap-4 min-h-0">
        {/* Left Sidebar Actions */}
        <div className="w-48 flex flex-col gap-3">
          <ActionButton 
            label="VACANT" 
            isActive={status === 'vacant'} 
            activeColor="bg-[#8BAE3A]" 
            borderColor="border-[#8BAE3A]"
            glowColor="shadow-[#8BAE3A]/50"
            onClick={handleVacant} 
          />
          <ActionButton 
            label="HIRED" 
            isActive={status === 'hired'} 
            activeColor="bg-sky-400" 
            borderColor="border-sky-400"
            glowColor="shadow-sky-400/50"
            onClick={handleHired} 
          />
          <ActionButton 
            label="STOP/PRINT" 
            isActive={status === 'stopped'} 
            activeColor="bg-red-500" 
            borderColor="border-red-500"
            glowColor="shadow-red-500/50"
            onClick={handleStop} 
          />
          <ActionButton 
            label="MEMORY" 
            isActive={false} 
            activeColor="bg-gray-500" 
            borderColor="border-gray-500"
            glowColor=""
            onClick={() => setShowMemory(true)} 
          />
        </div>

        {/* Middle Stats - Lime Green */}
        <div className="flex-[3] flex flex-col border-[6px] border-black bg-[#C4F26B] text-black">
          {/* Top: Fare */}
          <div className="flex-[2] border-b-[6px] border-black flex flex-col p-4 relative">
            <div className="absolute top-4 left-1/2 -translate-x-1/2 flex items-center bg-[#3a3f47] rounded text-gray-300 px-3 py-1 gap-4 shadow-md">
              <button className="text-xl font-bold hover:text-white">-</button>
              <div className="w-5 h-5 border-2 border-current rounded-full flex items-center justify-center">
                <div className="w-2 h-2 bg-current rounded-full" />
              </div>
              <button className="text-xl font-bold hover:text-white">+</button>
            </div>
            
            <div className="flex-1 flex items-center justify-center">
              <span className="text-7xl font-black mr-8 line-through decoration-double">P</span>
              <span className="text-[130px] font-black tracking-tighter">
                {fare.toFixed(2)}
              </span>
            </div>
          </div>
          {/* Middle: Distance & Time */}
          <div className="flex-[1.5] flex border-b-[6px] border-black">
            <div className="flex-1 border-r-[6px] border-black p-4 flex flex-col justify-between">
              <div className="text-lg font-bold">DISTANCE KM:</div>
              <div className="text-6xl font-black text-center mb-4">{distance.toFixed(1)} KM</div>
            </div>
            <div className="flex-1 p-4 flex flex-col justify-between">
              <div className="text-lg font-bold">TIME:</div>
              <div className="text-6xl font-black text-center mb-4">{elapsed}</div>
            </div>
          </div>
          {/* Bottom: Plate & Driver Name */}
          <div className="flex-[0.5] flex bg-white">
            <div className="flex-[0.4] border-r-[6px] border-black p-3 flex items-center justify-center">
              <div className="text-xl font-black">NXZ-123</div>
            </div>
            <div className="flex-[0.6] p-3 flex items-center pl-6">
              <div className="text-xl font-black truncate">JUAN DELA CRUZ</div>
            </div>
          </div>
        </div>

        {/* Right Profile - White */}
        <div className="flex-[1.5] border-[6px] border-black border-l-0 bg-white flex flex-col items-center py-8 px-4">
          <div className="text-2xl font-black text-black mb-12">ID:123456</div>
          <div className="relative w-64 h-64 rounded-full overflow-hidden border-0">
            <img 
              src="https://randomuser.me/api/portraits/men/32.jpg" 
              alt="Driver Profile" 
              className="w-full h-full object-cover"
            />
          </div>
        </div>
      </div>

      {/* Memory Summary Modal */}
      {showMemory && (
        <MemorySummaryModal onClose={() => setShowMemory(false)} />
      )}
    </div>
  );
}

function ActionButton({ label, isActive, activeColor, borderColor, glowColor, onClick }: any) {
  return (
    <button
      onClick={onClick}
      className={`flex-1 rounded-lg border-2 flex items-center justify-center transition-all ${
        isActive 
          ? `${activeColor} ${borderColor} ${glowColor} shadow-[0_0_15px_rgba(0,0,0,0.5)] bg-opacity-80` 
          : 'bg-[#222A3A] border-[#38445A]'
      }`}
    >
      <span className={`text-xl font-black tracking-wider ${isActive ? 'text-white' : 'text-[#B0C4DE]'}`}>
        {label}
      </span>
    </button>
  );
}

function MemorySummaryModal({ onClose }: { onClose: () => void }) {
  const dummyTrips = [
    { id: 1, date: 'June 1, 2026', start: '7:40 AM', end: '8:10 AM', distance: '8.4', fare: 400 },
    { id: 2, date: 'June 1, 2026', start: '8:15 AM', end: '8:30 AM', distance: '3.2', fare: 150 },
    { id: 3, date: 'June 1, 2026', start: '9:00 AM', end: '9:45 AM', distance: '12.5', fare: 650 },
  ];

  const totalFare = dummyTrips.reduce((acc, curr) => acc + curr.fare, 0);
  const totalKm = dummyTrips.reduce((acc, curr) => acc + parseFloat(curr.distance), 0);

  return (
    <div className="absolute inset-0 bg-black/60 z-50 flex items-center justify-center p-8 backdrop-blur-sm">
      <div className="w-full max-w-5xl h-full max-h-[800px] bg-white border-[3px] border-black flex flex-col shadow-2xl">
        
        {/* Header */}
        <div className="flex border-b-[3px] border-black">
          <div className="flex-[3] p-4 flex items-center">
            <h2 className="text-black text-2xl font-black">Memory Summary Trips</h2>
          </div>
          <button className="flex-1 bg-[#C4F26B] border-l-[3px] border-black flex items-center justify-center font-bold text-black text-lg hover:bg-[#b0d960]">
            Print
          </button>
          <button 
            onClick={onClose}
            className="flex-1 bg-[#FFB74D] border-l-[3px] border-black flex items-center justify-center font-bold text-black text-lg hover:bg-[#e5a445]"
          >
            back to operation
          </button>
        </div>

        {/* Table Header */}
        <div className="flex border-b-[3px] border-black bg-gray-50">
          <div className="flex-1 p-3 border-r-[3px] border-black text-center font-bold text-black text-sm">Date</div>
          <div className="flex-1 p-3 border-r-[3px] border-black text-center font-bold text-black text-sm">Start -Time</div>
          <div className="flex-1 p-3 border-r-[3px] border-black text-center font-bold text-black text-sm">End -Time</div>
          <div className="flex-1 p-3 border-r-[3px] border-black text-center font-bold text-black text-sm">Distance Km</div>
          <div className="flex-1 p-3 text-center font-bold text-black text-sm">Fare</div>
        </div>

        {/* Table Body */}
        <div className="flex-1 overflow-auto bg-white">
          {dummyTrips.map(trip => (
            <div key={trip.id} className="flex border-b-[3px] border-black">
              <div className="flex-1 p-4 border-r-[3px] border-black text-center font-bold text-black text-sm">{trip.date}</div>
              <div className="flex-1 p-4 border-r-[3px] border-black text-center font-bold text-black text-sm">{trip.start}</div>
              <div className="flex-1 p-4 border-r-[3px] border-black text-center font-bold text-black text-sm">{trip.end}</div>
              <div className="flex-1 p-4 border-r-[3px] border-black text-center font-bold text-black text-sm">{trip.distance}Km</div>
              <div className="flex-1 p-4 text-center font-bold text-black text-sm">₱{trip.fare}</div>
            </div>
          ))}
          {/* Fill remaining space with empty lines if needed, or just let it be empty */}
          {[1,2,3,4].map(i => (
            <div key={`empty-${i}`} className="flex border-b-[3px] border-black min-h-[56px]">
              <div className="flex-1 border-r-[3px] border-black"></div>
              <div className="flex-1 border-r-[3px] border-black"></div>
              <div className="flex-1 border-r-[3px] border-black"></div>
              <div className="flex-1 border-r-[3px] border-black"></div>
              <div className="flex-1"></div>
            </div>
          ))}
        </div>

        {/* Footer */}
        <div className="flex border-t-[3px] border-black bg-gray-50">
          <div className="flex-[2] border-r-[3px] border-black p-3"></div>
          <div className="flex-1 border-r-[3px] border-black p-3 flex items-center">
            <span className="text-black text-xs font-bold">Total trip Time: 1h 30m</span>
          </div>
          <div className="flex-1 border-r-[3px] border-black p-3 flex items-baseline gap-1">
            <span className="text-black text-xs font-bold">Total Km:</span>
            <span className="text-black text-lg font-black">{totalKm.toFixed(1)}Km</span>
          </div>
          <div className="flex-1 p-3 flex items-baseline gap-1">
            <span className="text-black text-xs font-bold">Total Fare:</span>
            <span className="text-black text-lg font-black">₱{totalFare.toFixed(0)}</span>
          </div>
        </div>

      </div>
    </div>
  );
}
