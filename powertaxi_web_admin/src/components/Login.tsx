import React, { useState } from 'react';
import { authenticateUser } from '../services/firebase';
import type { AppUser } from '../services/firebase';
import { 
  Bolt, 
  Lock, 
  Mail, 
  Eye, 
  EyeOff, 
  AlertCircle,
  ShieldCheck,
  Globe
} from 'lucide-react';

interface LoginProps {
  onLoginSuccess: (user: AppUser) => void;
}

export const Login: React.FC<LoginProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password) {
      setError('Please fill in all credentials fields.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const user = await authenticateUser(email, password);
      onLoginSuccess(user);
    } catch (err: any) {
      setError(err?.message || 'Invalid email or password.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full bg-bg flex items-center justify-center p-6 relative overflow-hidden font-sans">
      
      {/* Premium Background Ambient Blobs */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] bg-accentOrange/10 rounded-full blur-[120px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-blue-900/20 rounded-full blur-[120px] pointer-events-none"></div>

      {/* Main Glassmorphic Wrapper */}
      <div className="w-full max-w-4xl bg-[#0D1017]/80 border border-borderDark rounded-3xl overflow-hidden shadow-2xl flex flex-col md:flex-row relative z-10 backdrop-blur-md">
        
        {/* Left Interactive Branding Column (Desktop only) */}
        <div className="hidden md:flex md:w-1/2 bg-gradient-to-br from-[#10141D] to-[#0A0D14] p-12 flex-col justify-between border-r border-borderDark/40">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-accentOrange rounded-lg flex items-center justify-center text-black shadow-lg shadow-accentOrange/20">
              <Bolt size={18} strokeWidth={2.5} className="animate-pulse" />
            </div>
            <span className="font-black text-sm tracking-wider uppercase text-white">
              PowerTaxi
            </span>
          </div>

          <div className="space-y-4 my-auto pr-6">
            <h1 className="text-3xl font-black text-white leading-tight">
              Real-Time Taxi Fleet Command Center
            </h1>
            <p className="text-xs text-textFaint leading-relaxed">
              Monitor active trip dispatches, review driver registration lists, update pulse-meter settings, and inspect comprehensive tax records from one central interface.
            </p>
          </div>

          <div className="flex items-center gap-6 text-[10px] text-textFaint font-semibold uppercase tracking-wider">
            <span className="flex items-center gap-1">
              <ShieldCheck size={12} className="text-emerald-500" /> Secure SSL
            </span>
            <span className="flex items-center gap-1">
              <Globe size={12} className="text-blue-500" /> Parity Platform
            </span>
          </div>
        </div>

        {/* Right Form Fields Column */}
        <div className="w-full md:w-1/2 p-8 sm:p-12 flex flex-col justify-center">
          
          {/* Logo header for compact screens */}
          <div className="flex items-center gap-3 mb-6 md:hidden">
            <div className="w-8 h-8 bg-accentOrange rounded-lg flex items-center justify-center text-black shadow-lg shadow-accentOrange/20">
              <Bolt size={18} strokeWidth={2.5} />
            </div>
            <span className="font-black text-sm tracking-wider uppercase text-white">
              PowerTaxi
            </span>
          </div>

          <div className="space-y-2 mb-8">
            <h2 className="text-2xl font-black text-white">Welcome Back</h2>
            <p className="text-xs text-textFaint font-semibold">Sign in to manage your system operator tools.</p>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-5">
            
            {/* Error Notification Banner */}
            {error && (
              <div className="p-3.5 bg-red-950/20 border border-red-950/50 rounded-xl text-xs text-red-400 font-semibold flex items-start gap-2.5 animate-headShake">
                <AlertCircle size={16} className="shrink-0 mt-0.5" />
                <span>{error}</span>
              </div>
            )}

            {/* Email Field */}
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">Email Address</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-3 text-textFaint" size={16} />
                <input 
                  type="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@powertaxi.com"
                  required
                  className="w-full pl-11 pr-4 py-3 bg-[#1A1E26]/50 border border-borderDark rounded-xl text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange focus:ring-1 focus:ring-accentOrange/25 transition-all"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-[10px] font-bold text-textFaint uppercase tracking-wider block">Security Password</label>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-3 text-textFaint" size={16} />
                <input 
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  required
                  className="w-full pl-11 pr-11 py-3 bg-[#1A1E26]/50 border border-borderDark rounded-xl text-xs text-white placeholder-textFaint/60 focus:outline-none focus:border-accentOrange focus:ring-1 focus:ring-accentOrange/25 transition-all"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-3 text-textFaint hover:text-white transition-colors"
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 px-4 bg-accentOrange hover:bg-accentOrange/90 text-black text-xs font-black uppercase tracking-wider rounded-xl transition-all shadow-lg shadow-accentOrange/10 hover:shadow-accentOrange/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 mt-2"
            >
              {loading ? (
                <>
                  <div className="w-4 h-4 animate-spin rounded-full border-2 border-black border-t-transparent"></div>
                  <span>Authenticating...</span>
                </>
              ) : (
                <span>Sign In to Dashboard</span>
              )}
            </button>

          </form>

          {/* Operator Demo Hint Info banner */}
          <div className="mt-8 p-3 bg-white/5 border border-borderDark/60 rounded-xl text-[10px] text-textFaint leading-relaxed">
            <span className="font-bold text-white block mb-0.5">ℹ️ System Operator Hint:</span>
            Default system administrators can log in using their operator email address and password credentials (e.g. initial `password123` or your customized personnel profiles).
          </div>

        </div>

      </div>

    </div>
  );
};
