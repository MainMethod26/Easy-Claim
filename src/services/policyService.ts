import { PolicyModel } from '../models/policyModel';

export class PolicyService {
  static async getMyCovers(db: any, userId: string) {
    return await PolicyModel.getMyCovers(db, userId);
  }

  static getMarketCatalog() {
    return [
      { id: 'cat_01', provider: 'Discovery Health', name: 'Smart Plan', premium: 'R 2,450 / month' },
      { id: 'cat_02', provider: 'Sanlam', name: 'Comprehensive Life Cover', premium: 'R 850 / month' },
      { id: 'cat_03', provider: 'OUTsurance', name: 'Home & Contents Cover', premium: 'R 1,100 / month' },
      { id: 'cat_04', provider: 'Momentum', name: 'Ingwe Network Health', premium: 'R 540 / month' },
      { id: 'cat_05', provider: 'Old Mutual', name: 'Protect Family Funeral Plan', premium: 'R 150 / month' }
    ];
  }

  static processRequirements(body: any) {
    const insuranceType = body.insurance_type;
    let capturedData: any = {};
    
    if (insuranceType === 'Mobile Device Insurance') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA'],
        customer_identity_kyc: body.customer_identity_kyc,
        asset_specific_details: body.asset_specific_details,
        risk_and_underwriting: body.risk_and_underwriting,
        financial_and_settlement: body.financial_and_settlement
      };
    } else if (insuranceType === 'Home Insurance (Building Structure & Contents)') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'Short-Term Insurance Act'],
        customer_identity_kyc: body.customer_identity_kyc,
        property_and_asset_details: body.property_and_asset_details,
        risk_and_compliance: body.risk_and_compliance,
        financial_and_settlement: body.financial_and_settlement
      };
    } else if (insuranceType === 'Motor Vehicle Insurance') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'National Road Traffic Act'],
        customer_identity_kyc: body.customer_identity_kyc,
        asset_specific_details: body.asset_specific_details,
        risk_and_underwriting: body.risk_and_underwriting,
        legal_and_consent: body.legal_and_consent
      };
    } else {
      return null;
    }
    
    return capturedData;
  }
}
