export class IdentityService {
  static getProfile(userId: string) {
    return {
      id: userId,
      firstName: 'Sipho',
      lastName: 'Nkosi',
      idNumber: '8505125021087',
      email: 'sipho.nkosi@example.co.za',
      phone: '+27 82 123 4567',
      address: '123 Nelson Mandela Drive, Sandton, 2196',
      riskProfile: 'Low',
      kycStatus: 'Verified'
    };
  }

  static updateProfile(data: any) {
    return data;
  }

  static getConsents() {
    return [
      { id: 'c_popia', name: 'POPIA Data Processing', status: 'Granted', date: '2023-01-15' },
      { id: 'c_marketing', name: 'Marketing Communications', status: 'Declined', date: '2023-01-15' },
      { id: 'c_medical', name: 'Medical Records Sharing (Discovery)', status: 'Granted', date: '2023-06-22' }
    ];
  }

  static checkMandate(tenantId: string) {
    return { 
      tenantId: tenantId,
      mandateActive: true,
      amount: 'R 850.00',
      nextDeduction: '2023-11-01',
      bankName: 'Standard Bank',
      accountEnding: '4567'
    };
  }
  
  static cancelMandate() {
    return { 
      status: 'success',
      message: 'Debit order mandate successfully cancelled.',
      cancellationDate: new Date().toISOString()
    };
  }

  static login(idNumber: string) {
    if (idNumber === '8505125021087') {
      return {
        status: 'success',
        message: 'Login successful',
        token: 'mock-jwt-token-123',
        profile: this.getProfile('user123')
      };
    }
    return null;
  }
}
