import { create } from 'zustand';
import { HomeDashboardState, ClaimSummary, ClaimsWizardData, PolicyCover } from '../types';

interface AppState {
  // Navigation
  activeTab: 'Home' | 'Covers' | 'Activities' | 'Profile';
  setActiveTab: (tab: 'Home' | 'Covers' | 'Activities' | 'Profile') => void;

  // Home Dashboard Data
  homeDashboard: HomeDashboardState;
  setHomeDashboard: (data: Partial<HomeDashboardState>) => void;

  // Covers State
  myCovers: PolicyCover[];
  marketCatalog: PolicyCover[];
  setCovers: (myCovers: PolicyCover[], catalog: PolicyCover[]) => void;

  // Claims Wizard State
  activeClaimWizard: ClaimsWizardData | null;
  wizardCurrentStep: number;
  startClaimWizard: (policyId: string) => void;
  updateWizardData: (data: Partial<ClaimsWizardData>) => void;
  nextWizardStep: () => void;
  prevWizardStep: () => void;
  submitWizard: () => Promise<void>;
  resetWizard: () => void;
}

export const useAppStore = create<AppState>((set, get) => ({
  activeTab: 'Home',
  setActiveTab: (tab) => set({ activeTab: tab }),

  homeDashboard: {
    claimStatuses: [],
    mostVisited: [],
    recentActivity: [],
    notifications: []
  },
  setHomeDashboard: (data) => set((state) => ({ 
    homeDashboard: { ...state.homeDashboard, ...data } 
  })),

  myCovers: [],
  marketCatalog: [],
  setCovers: (myCovers, catalog) => set({ myCovers, marketCatalog: catalog }),

  activeClaimWizard: null,
  wizardCurrentStep: 1,
  startClaimWizard: (policyId) => set({
    wizardCurrentStep: 1,
    activeClaimWizard: {
      category: undefined,
      verifiedContext: { isIdentityValid: false, isPolicyActive: false, waitingPeriodCleared: false },
      screeningEvidence: { causeOfLoss: '', incidentDate: '' },
      supportingDocs: [],
      reviewSummaryApproved: false
    }
  }),
  updateWizardData: (data) => set((state) => ({
    activeClaimWizard: state.activeClaimWizard ? { ...state.activeClaimWizard, ...data } : null
  })),
  nextWizardStep: () => set((state) => ({ 
    wizardCurrentStep: Math.min(state.wizardCurrentStep + 1, 6) 
  })),
  prevWizardStep: () => set((state) => ({ 
    wizardCurrentStep: Math.max(state.wizardCurrentStep - 1, 1) 
  })),
  submitWizard: async () => {
    // API Call to POST /api/v1/claims/submit-wizard
    console.log("Submitting claim...", get().activeClaimWizard);
    set({ wizardCurrentStep: 6 }); // Move to Step 6: Status & Tracking
  },
  resetWizard: () => set({ activeClaimWizard: null, wizardCurrentStep: 1 })
}));
