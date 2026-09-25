// 1. Core Tab Navigation Types
export type TabName = 'Home' | 'Covers' | 'Activities' | 'Profile';

// 2. Home Screen Types
export interface ClaimSummary {
  id: string;
  policyName: string;
  stage: 'Submitted' | 'Verified' | 'Screening' | 'Review' | 'Decision' | 'Paid';
  subState?: 'Info Needed' | 'Rejected' | 'Appeal';
  lastUpdated: string;
}

export interface Activity {
  id: string;
  date: string;
  action: string;
}

export interface Notification {
  id: string;
  type: 'Alert' | 'Reminder' | 'Update';
  message: string;
  requiresAction: boolean;
}

export interface HomeDashboardState {
  claimStatuses: ClaimSummary[];
  mostVisited: string[];
  recentActivity: Activity[];
  notifications: Notification[];
}

// 3. Covers Screen & Marketplace Types
export interface PolicyCover {
  id: string;
  provider: string;
  planName: string;
  premium: string;
  isActive: boolean;
}

export interface JoinRequestData {
  planId: string;
  provider: string;
  personalDetails: Record<string, any>;
}

// 4. Claims Wizard Types (6-Stage)
export type ClaimCategory = 'Medical' | 'Vehicle' | 'Life' | 'Property' | 'Other';

export interface ClaimsWizardData {
  category?: ClaimCategory;
  verifiedContext: {
    isIdentityValid: boolean;
    isPolicyActive: boolean;
    waitingPeriodCleared: boolean;
  };
  screeningEvidence: {
    causeOfLoss: string;
    incidentDate: string;
  };
  supportingDocs: string[]; // URLs or file refs
  reviewSummaryApproved: boolean;
}
