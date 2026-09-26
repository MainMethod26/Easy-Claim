export class GatewayService {
  static getHomeData() {
    return { 
      message: 'Welcome to EasyClaim SA',
      alerts: [
        "Your OUTsurance claim #claim_out_101 is being reviewed.",
        "Discovery Health updated their claim submission guidelines."
      ]
    };
  }
  
  static getMostVisitedServices() {
    return [
      { service: 'Submit Medical Claim (Discovery)' },
      { service: 'View Life Policy (Sanlam)' },
      { service: 'Log Car Accident (OUTsurance)' }
    ];
  }
  
  static getNotifications() {
    return [
      { type: 'Update', message: 'Momentum Health approved your recent pharmacy claim.' },
      { type: 'Reminder', message: 'Old Mutual premium of R150 is due on the 1st.' }
    ];
  }
  
  static getRecentActivity() {
    return [
      { date: '2023-10-15', action: 'Uploaded hospital invoice for Discovery Health.' },
      { date: '2023-10-10', action: 'Canceled mandate for old insurance provider.' }
    ];
  }
}
