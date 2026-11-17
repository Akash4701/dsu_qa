public with sharing class FeeAssignmentHandler {
    
    // Called from Program Enrollment Trigger (After Insert)
    public static void prepareAndCreateFeeAssignments(List<hed__Program_Enrollment__c> enrollments) {
        if (enrollments == null || enrollments.isEmpty()) return;
        
        Set<Id> affiliationIds = new Set<Id>();
        Set<Id> termIds = new Set<Id>();
        
        for (hed__Program_Enrollment__c pe : enrollments) {
            if (pe.hed__Affiliation__c != null) affiliationIds.add(pe.hed__Affiliation__c);
            if (pe.Term__c != null) termIds.add(pe.Term__c);
        }
        
        if (affiliationIds.isEmpty() || termIds.isEmpty()) return;
        
        // Fetch affiliations with Fee Preference & Contact
        Map<Id, hed__Affiliation__c> affMap = new Map<Id, hed__Affiliation__c>([
            SELECT Id, hed__Contact__c, Individual_Application__r.Fee_Preference__c
            FROM hed__Affiliation__c
            WHERE Id IN :affiliationIds
        ]);
        
        // Collect Fee Preferences
        Set<String> feePrefs = new Set<String>();
        for (hed__Affiliation__c aff : affMap.values()) {
            if (aff.Individual_Application__r != null &&
                String.isNotBlank(aff.Individual_Application__r.Fee_Preference__c)) {
                    feePrefs.add(aff.Individual_Application__r.Fee_Preference__c);
                }
        }
        if (feePrefs.isEmpty()) return;
        
        // Fetch Fee Types for relevant Terms and Preferences
        List<Fee_Type__c> feeTypes = [
            SELECT Id, Fee_Preference__c, Fee_Head__c, Amount__c, Semester__c
            FROM Fee_Type__c
            WHERE Semester__c IN :termIds
            AND Fee_Preference__c IN :feePrefs
        ];
        if (feeTypes.isEmpty()) return;
        
        // Group Fee Types by Term
        Map<Id, List<Fee_Type__c>> termToFeeTypes = new Map<Id, List<Fee_Type__c>>();
        for (Fee_Type__c ft : feeTypes) {
            if (ft.Semester__c == null) continue;
            if (!termToFeeTypes.containsKey(ft.Semester__c)) {
                termToFeeTypes.put(ft.Semester__c, new List<Fee_Type__c>());
            }
            termToFeeTypes.get(ft.Semester__c).add(ft);
        }
        
        // prevent duplicate Fee Assignments
        Map<String, Boolean> existingKeys = new Map<String, Boolean>();
        for (Fee_Assignment__c fa : [
            SELECT Id, Affiliation__c, Fee_Type__r.Semester__c
            FROM Fee_Assignment__c
            WHERE Affiliation__c IN :affiliationIds
            AND Fee_Type__r.Semester__c IN :termIds
        ]) {
            existingKeys.put(fa.Affiliation__c + '-' + fa.Fee_Type__r.Semester__c, true);
        }
        
        List<Fee_Assignment__c> feeAssignments = new List<Fee_Assignment__c>();
        
        // Create Fee Assignments
        for (hed__Program_Enrollment__c pe : enrollments) {
            hed__Affiliation__c aff = affMap.get(pe.hed__Affiliation__c);
            if (aff == null || aff.Individual_Application__r == null) continue;
            
            String pref = aff.Individual_Application__r.Fee_Preference__c;
            if (String.isBlank(pref) || pref == 'Program-wise fee') continue;
            
            List<Fee_Type__c> matchingFeeTypes = termToFeeTypes.get(pe.Term__c);
            if (matchingFeeTypes == null || matchingFeeTypes.isEmpty()) continue;
            
            for (Fee_Type__c ft : matchingFeeTypes) {
                if (ft.Fee_Preference__c == pref) {
                    
                    // Skip if duplicate exists
                    String key = aff.Id + '-' + ft.Semester__c;
                    if (existingKeys.containsKey(key)) continue;
                    
                    feeAssignments.add(new Fee_Assignment__c(
                        Affiliation__c = aff.Id,
                        Contact__c = aff.hed__Contact__c,
                        Fee_Type__c = ft.Id,
                        Fee_Head__c = ft.Fee_Head__c,
                        Fee_Preference__c = pref,
                        Remaining_Amount__c = ft.Amount__c,
                        Total_Amount_Payable__c = ft.Amount__c,
                        Scholarship_Amount__c = 0,
                        Is_Active__c = true
                    ));
                    existingKeys.put(key, true);
                    break;
                }
            }
        }
        
        if (feeAssignments.isEmpty()) return;
        
        insert feeAssignments;
        
        // Create corresponding Fee Installments
        List<Fee_Installment__c> installments = new List<Fee_Installment__c>();
        for (Fee_Assignment__c fa : feeAssignments) {
            installments.add(new Fee_Installment__c(
                Fee_Assignment__c = fa.Id,
                Fee_Type__c = fa.Fee_Type__c,
                Affiliation__c = fa.Affiliation__c,
                Contact__c = fa.Contact__c,
                Remaining_Amount__c = fa.Remaining_Amount__c,
                Total_Amount_Payable__c = fa.Total_Amount_Payable__c,
                Scholarship_Amount__c = 0
            ));
        }
        
        if (!installments.isEmpty()) {
            insert installments;
        }
    }
    //----------------------------------------------------Scholarship Calculations-----------------------------------------------
    public static void calculateScholarship(
        List<Fee_Assignment__c> newList,
        Map<Id, Fee_Assignment__c> oldMap
    ) {
        // Collect scholarship ids
        Set<Id> scholarshipIds = new Set<Id>();
        for (Fee_Assignment__c fa : newList) {
            if (fa.Scholarship__c != null) {
                scholarshipIds.add(fa.Scholarship__c);
            }
        }
        if (scholarshipIds.isEmpty()) {
            return;
        }

        // Query scholarships (adjust API names)
        Map<Id, Fee_Discount__c> scholarshipById = new Map<Id, Fee_Discount__c>(
            [
                SELECT Id,
                       Discount_Amount__c,
                       Discount_Percentage__c,
                       Discount_Type__c      // 'Amount' / 'Percentage'
                FROM Fee_Discount__c
                WHERE Id IN :scholarshipIds
            ]
        );

        for (Fee_Assignment__c fa : newList) {
            if (fa.Scholarship__c == null) {
                continue;
            }

            Fee_Discount__c sch = scholarshipById.get(fa.Scholarship__c);
            if (sch == null) {
                continue;
            }

            // Use old Remaining_Amount__c as base if needed
            Decimal baseRemaining = fa.Fee_Amount__c;
            if (oldMap != null && oldMap.containsKey(fa.Id)) {
                // Optional: avoid compounding discount on every update
                Fee_Assignment__c oldFa = oldMap.get(fa.Id);
                baseRemaining = oldFa.Fee_Amount__c;
            }

            Decimal scholarshipAmount = 0;
            if (sch.Discount_Type__c == 'Amount') {
                scholarshipAmount = sch.Discount_Amount__c;
            } else if (sch.Discount_Type__c == 'Percentage') {
                // Percentage of base remaining
                scholarshipAmount =
                    (baseRemaining * (sch.Discount_Percentage__c == null
                        ? 0
                        : sch.Discount_Percentage__c)) / 100;
            }

            // Guard against null and negative
            if (scholarshipAmount == null) scholarshipAmount = 0;
            if (scholarshipAmount > baseRemaining) {
                scholarshipAmount = baseRemaining;
            }

            fa.Scholarship_Amount__c = scholarshipAmount;

            Decimal payable = baseRemaining - scholarshipAmount;
            fa.Total_Amount_Payable__c = payable;

            Decimal paidAmount = fa.Paid_Amount__c == null
            ? 0
            : fa.Paid_Amount__c;

            fa.Remaining_Amount__c = Math.max(0, payable - paidAmount);
        }
    }
    
     public static void updateInstallments(List<Fee_Assignment__c> feeAssignments) {
    Set<Id> faIds = new Set<Id>();
    Map<Id, Fee_Assignment__c> faById = new Map<Id, Fee_Assignment__c>();
    for (Fee_Assignment__c fa : feeAssignments) {
        if (fa.Id != null) {
            faIds.add(fa.Id);
            faById.put(fa.Id, fa);
        }
    }
    if (faIds.isEmpty()) return;

    // Query installments grouped by FA
    Map<Id, List<Fee_Installment__c>> instByFa = new Map<Id, List<Fee_Installment__c>>();
    for (Fee_Installment__c inst : [
        SELECT Id, Fee_Assignment__c, Fee_Amount__c,
               Scholarship_Amount__c, Remaining_Amount__c,Paid_Amount__c
        FROM Fee_Installment__c
        WHERE Fee_Assignment__c IN :faIds
    ]) {
        if (!instByFa.containsKey(inst.Fee_Assignment__c)) {
            instByFa.put(inst.Fee_Assignment__c, new List<Fee_Installment__c>());
        }
        instByFa.get(inst.Fee_Assignment__c).add(inst);
    }

    List<Fee_Installment__c> toUpdate = new List<Fee_Installment__c>();

    for (Id faId : instByFa.keySet()) {
        Fee_Assignment__c fa = faById.get(faId);
        if (fa == null || fa.Scholarship_Amount__c == null) continue;

        List<Fee_Installment__c> instList = instByFa.get(faId);
        if (instList.isEmpty()) continue;

        Decimal parentScholarship = fa.Scholarship_Amount__c;
        Decimal totalInstallmentFee = 0;
        for (Fee_Installment__c i : instList) {
            totalInstallmentFee += (i.Fee_Amount__c == null ? 0 : i.Fee_Amount__c);
        }

        // Example: proportional split for both Amount and Percentage parent discount
        Decimal allocatedSoFar = 0;
        for (Integer idx = 0; idx < instList.size(); idx++) {
            Fee_Installment__c inst = instList[idx];

            Decimal instScholarship;
            if (idx == instList.size() - 1) {
                // Last one gets the remainder to fix rounding
                instScholarship = parentScholarship - allocatedSoFar;
            } else if (totalInstallmentFee != 0) {
                instScholarship =
                    (inst.Fee_Amount__c / totalInstallmentFee) * parentScholarship;
                instScholarship = instScholarship.setScale(2); // optional
            } else {
                instScholarship = 0;
            }

            if (instScholarship < 0) instScholarship = 0;
            if (instScholarship > inst.Fee_Amount__c) {
                instScholarship = inst.Fee_Amount__c;
            }

            allocatedSoFar += instScholarship;

            Decimal payable = inst.Fee_Amount__c - instScholarship;

            Decimal paidAmount = inst.Paid_Amount__c == null
            ? 0
            : inst.Paid_Amount__c;

            inst.Scholarship_Amount__c = instScholarship;
            inst.Total_Amount_Payable__c = payable;
            inst.Remaining_Amount__c = Math.max(0, payable - paidAmount);

            toUpdate.add(inst);
        }
    }

    if (!toUpdate.isEmpty()) {
        update toUpdate;
    }
}
    
}