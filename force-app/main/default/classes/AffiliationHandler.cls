public class AffiliationHandler {
    public class email{
        public String dsuemail = '@dsuonline.in';
    }
    
    public static void generateRollNumbers(List<hed__Affiliation__c> affiliations) {
        Set<Id> programPlanIds = new Set<Id>();
        
        // Collect Program Plan Ids
        for (hed__Affiliation__c aff : affiliations) {
            if (aff.Program_Plan__c != null && String.isBlank(aff.Roll_Number__c)) {
                programPlanIds.add(aff.Program_Plan__c);
            }
        }
        
        // Fetch Program Plans with related fields and FOR UPDATE lock
        Map<Id, hed__Program_Plan__c> planMap = new Map<Id, hed__Program_Plan__c>(
            [SELECT Id, Batch__c, Intake_Number__c, Sequence_Number__c,Academic_Year__c,
             hed__Account__r.Alias__c,
             hed__Account__r.Parent.Parent.Institute_Code__c
             FROM hed__Program_Plan__c 
             WHERE Id IN :programPlanIds
             FOR UPDATE]
        );
        
        // Prepare to update Sequence_Number__c
        List<hed__Program_Plan__c> plansToUpdate = new List<hed__Program_Plan__c>();
        
        // Local map to track current sequence per plan
        Map<Id, Integer> nextSeqMap = new Map<Id, Integer>();
        
        // Loop through affiliations and assign Roll Number
        for (hed__Affiliation__c aff : affiliations) {
            if (aff.Program_Plan__c != null && String.isBlank(aff.Roll_Number__c) &&String.isNotBlank(aff.DEB_ID__c) && aff.Individual_Application__r.Status__c == 'Approved for USN') {
                hed__Program_Plan__c plan = planMap.get(aff.Program_Plan__c);
                
                if (plan != null &&
                    plan.hed__Account__r != null &&
                    plan.hed__Account__r.Parent != null &&
                    plan.hed__Account__r.Parent.Parent != null) {
                        
                        // Derive prefix
                        String yearStr = String.valueOf(plan.Academic_Year__c);
                        String lastTwoDigits = yearStr.substring(2, 4);
                        String prefix = plan.hed__Account__r.Parent.Parent.Institute_Code__c +
                            lastTwoDigits +
                            plan.Intake_Number__c +
                            plan.hed__Account__r.Alias__c;
                        
                        // Determine next sequence number
                        Integer nextSeq = nextSeqMap.containsKey(plan.Id)
                            ? nextSeqMap.get(plan.Id) + 1
                            : (plan.Sequence_Number__c == null ? 0001 : plan.Sequence_Number__c.intValue());
                                
                                
                                // Store updated sequence in maps
                                nextSeqMap.put(plan.Id, nextSeq);
                        plan.Sequence_Number__c = nextSeq + 1;
                        
                        if (!plansToUpdate.contains(plan)) {
                            plansToUpdate.add(plan);
                        }
                        Integer safeSeq = (nextSeq == null) ? 1 : nextSeq;
                        String paddedSeq = String.valueOf(safeSeq);
                        
                        
                        
                        // Pad sequence to 4 digits
                        //    String paddedSeq = String.valueOf(nextSeq);
                        while (paddedSeq.length() < 4) {
                            paddedSeq = '0' + paddedSeq;
                        }
                        email dsu = new email();
                        System.debug('BefAffil>>>>>>>>>>>>>>>>>>>'+aff.Id);
                        
                        
                        // Assign Roll Number
                        aff.Roll_Number__c = prefix + paddedSeq;
                        aff.DSU_Email__c = aff.Roll_Number__c +dsu.dsuemail;
                        //generateOfferLetter(aff.Id);
                        
                    }
            }
        }
        
        // Update Program Plan sequence values
        if (!plansToUpdate.isEmpty()) {
            update plansToUpdate;
        }
    }
    public static void MarkPrimaryAffiliation(List<hed__Affiliation__c> updatedAffs) {
        Set<Id> contactIds = new Set<Id>();
        Map<Id, hed__Affiliation__c> updatedAffMap = new Map<Id, hed__Affiliation__c>();

        for (hed__Affiliation__c aff : updatedAffs) {
            if (aff.hed__Contact__c != null) {
                contactIds.add(aff.hed__Contact__c);
                updatedAffMap.put(aff.Id, aff);
            }
        }

        if (contactIds.isEmpty()) return;

        // Step 1: Get sibling affiliations (excluding the updated ones)
        Map<Id, List<hed__Affiliation__c>> contactToSiblingsMap = new Map<Id, List<hed__Affiliation__c>>();
        List<hed__Affiliation__c> siblingAffs = [
            SELECT Id, hed__Contact__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIds
              AND Id NOT IN :updatedAffMap.keySet()
        ];

        for (hed__Affiliation__c aff : siblingAffs) {
            if (!contactToSiblingsMap.containsKey(aff.hed__Contact__c)) {
                contactToSiblingsMap.put(aff.hed__Contact__c, new List<hed__Affiliation__c>());
            }
            contactToSiblingsMap.get(aff.hed__Contact__c).add(aff);
        }

        // Step 2: Get sibling affiliation IDs to check enrollments
        Set<Id> siblingAffIds = new Set<Id>();
        for (List<hed__Affiliation__c> affList : contactToSiblingsMap.values()) {
            for (hed__Affiliation__c aff : affList) {
                siblingAffIds.add(aff.Id);
            }
        }

        // Step 3: Check which sibling affiliations are tied to enrollments
        Set<Id> affiliationsWithEnrollments = new Set<Id>();
        for (hed__Program_Enrollment__c enroll : [
            SELECT Id, hed__Affiliation__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Affiliation__c IN :siblingAffIds
        ]) {
            affiliationsWithEnrollments.add(enroll.hed__Affiliation__c);
        }

        // Step 4: Mark current ones as primary if no siblings have enrollments
        List<hed__Affiliation__c> toUpdate = new List<hed__Affiliation__c>();

        for (hed__Affiliation__c aff : updatedAffs) {
            if (aff.hed__Contact__c == null) continue;

            List<hed__Affiliation__c> siblings = contactToSiblingsMap.get(aff.hed__Contact__c);
            Boolean hasSiblingEnrollment = false;

            if (siblings != null) {
                for (hed__Affiliation__c sib : siblings) {
                    if (affiliationsWithEnrollments.contains(sib.Id)) {
                        hasSiblingEnrollment = true;
                        break;
                    }
                }
            }

            // Mark as primary only if no sibling has enrollments
            if (!hasSiblingEnrollment && aff.Is_Primary__c != true) {
                toUpdate.add(new hed__Affiliation__c(
                    Id = aff.Id,
                    Is_Primary__c = true
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    public static void UpdateApplicationSubstatus(List<hed__Affiliation__c> newAffList, Map<Id, hed__Affiliation__c> oldAffMap) {
        Map<Id, String> applicationStatusMap = new Map<Id, String>();
        
        for (hed__Affiliation__c newAff : newAffList) {
            if (newAff.Individual_Application__c != null) {
                Boolean isEmailActive = newAff.Is_DSU_Email_Active__c == true;
                Boolean isApproved = newAff.Approval_Status__c == 'Approved';
                
                if (isEmailActive) {
                    if (isApproved) {
                        // Safe to move to Email ID Active
                        applicationStatusMap.put(newAff.Individual_Application__c, 'Email ID Active');
                    } else {
                        newAff.Is_DSU_Email_Active__c.addError(' Registrar must approve the record before activating DSU Email.');
                    }
                } else if (isApproved) {
                    // If DSU Email is not active but status is Approved, update to Registrar Approved
                    if (!applicationStatusMap.containsKey(newAff.Individual_Application__c)) {
                        applicationStatusMap.put(newAff.Individual_Application__c, 'Registrar Approved');
                    }
                }
            }
        }
        
        if (!applicationStatusMap.isEmpty()) {
            List<Application__c> appsToUpdate = [
                SELECT Id, Sub_Status__c
                FROM Application__c
                WHERE Id IN :applicationStatusMap.keySet()
            ];
            
            for (Application__c app : appsToUpdate) {
                app.Sub_Status__c = applicationStatusMap.get(app.Id);
            }
            
            try {
                update appsToUpdate;
            } catch (Exception e) {
                System.debug('⚠️ Error updating Application Sub_Status: ' + e.getMessage());
            }
        }
    }
    
    @future
    public static void createFeeAssignmentsFromAffiliations(List<Id> affiliationIds) {

        try {
            if (affiliationIds == null || affiliationIds.isEmpty()) {
                System.debug('No affiliation IDs provided.');
                return;
            }

            // Fetch Affiliations with Fee_Preference__c
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, hed__Account__r.Name, hed__Contact__c, Program_Plan__c,
                    Individual_Application__r.Fee_Preference__c
                FROM hed__Affiliation__c 
                WHERE Id IN :affiliationIds
            ];

            Set<Id> programPlanIds = new Set<Id>();
            Set<String> feePreferences = new Set<String>();

            for (hed__Affiliation__c aff : affiliations) {
                if (aff.Program_Plan__c != null) {
                    programPlanIds.add(aff.Program_Plan__c);
                }
                if (aff.Individual_Application__r != null && aff.Individual_Application__r.Fee_Preference__c != null) {
                    feePreferences.add(aff.Individual_Application__r.Fee_Preference__c);
                }
            }

            if (programPlanIds.isEmpty()) {
                System.debug('No valid program plans found for provided affiliations.');
                return;
            }

            // Fetch only Semester 1 term for these Program Plans
            List<hed__Term__c> semesterOneTerms = [
                SELECT Id, Name, Program_Plan__c, Term_Reference__c
                FROM hed__Term__c
                WHERE Program_Plan__c IN :programPlanIds
                AND Term_Reference__c = 'Semester 1'
            ];

            // Map Program Plan → Set of "Semester 1" term names
            Map<Id, Set<String>> programPlanToSem1Terms = new Map<Id, Set<String>>();
            for (hed__Term__c term : semesterOneTerms) {
                if (!programPlanToSem1Terms.containsKey(term.Program_Plan__c)) {
                    programPlanToSem1Terms.put(term.Program_Plan__c, new Set<String>());
                }
                programPlanToSem1Terms.get(term.Program_Plan__c).add(term.Term_Reference__c);
            }

            // Fetch relevant Fee Types
            List<Fee_Type__c> feeTypes = [
                SELECT Id, Name, Semester__r.Name, Semester__r.Term_Reference__c,
                    Semester__r.Program_Plan__c, Amount__c, Fee_Preference__c, Fee_Head__c
                FROM Fee_Type__c
                WHERE Semester__r.Program_Plan__c IN :programPlanIds
                AND Fee_Preference__c IN :feePreferences
            ];

            List<Fee_Assignment__c> feeAssignmentsToInsert = new List<Fee_Assignment__c>();

            for (hed__Affiliation__c aff : affiliations) {
                Id programPlanId = aff.Program_Plan__c;
                String feePref = aff.Individual_Application__r != null ? aff.Individual_Application__r.Fee_Preference__c : null;

                if (programPlanId == null || feePref == null) continue;

                Boolean yearWiseAlreadyCreated = false;

                for (Fee_Type__c ft : feeTypes) {
                    if (ft.Semester__r == null) continue;
                    if (ft.Semester__r.Program_Plan__c != programPlanId) continue;
                    if (ft.Fee_Preference__c != feePref) continue;

                    Boolean isEligible = false;
                    String termRef = ft.Semester__r.Term_Reference__c;

                    // Only Semester 1 fees for semester-wise preference
                    if (feePref == 'Semester-wise fee') {
                        if (termRef != null && termRef.equalsIgnoreCase('Semester 1')) {
                            isEligible = true;
                        }
                    }
                    // Only one Year-wise fee per affiliation
                    else if (feePref == 'Year-wise fee') {
                        if (!yearWiseAlreadyCreated) {
                            isEligible = true;
                            yearWiseAlreadyCreated = true;
                        }
                    }
                    else if (feePref == 'Total program fee') {
                        isEligible = true;
                    }

                    if (isEligible) {
                        Fee_Assignment__c fa = new Fee_Assignment__c();
                        fa.Affiliation__c = aff.Id;
                        fa.Fee_Type__c = ft.Id;
                        fa.Fee_Head__c = ft.Fee_Head__c;
                        fa.Fee_Preference__c = feePref;
                        fa.Contact__c = aff.hed__Contact__c;
                        fa.Remaining_Amount__c = ft.Amount__c;
                        fa.Total_Amount_Payable__c = ft.Amount__c;
                        fa.Scholarship_Amount__c = 0;
                        fa.Is_Active__c = true;
                        feeAssignmentsToInsert.add(fa);
                    }
                }
            }

            if (!feeAssignmentsToInsert.isEmpty()) {
                insert feeAssignmentsToInsert;
                System.debug('Fee_Assignment__c records created successfully based on fee preference.');
                System.debug('Inserted Fee_Assignments: ' + feeAssignmentsToInsert);

                // Now create Fee_Installment__c records for each inserted Fee_Assignment__c
                List<Fee_Installment__c> installmentsToInsert = new List<Fee_Installment__c>();
    
                for (Fee_Assignment__c fa : feeAssignmentsToInsert) {
                    Fee_Installment__c installment = new Fee_Installment__c();
                    installment.Fee_Assignment__c = fa.Id;
                    installment.Fee_Type__c = fa.Fee_Type__c;
                    installment.Affiliation__c = fa.Affiliation__c;
                    installment.Contact__c = fa.Contact__c;
                    installment.Remaining_Amount__c = fa.Remaining_Amount__c;
                    installment.Total_Amount_Payable__c = fa.Total_Amount_Payable__c;
                    installment.Scholarship_Amount__c = 0;
                    installmentsToInsert.add(installment);
                }

                if (!installmentsToInsert.isEmpty()) {
                    insert installmentsToInsert;
                    System.debug('Inserted Fee_Installments: ' + installmentsToInsert);
                }
            } else {
                System.debug('No eligible Fee_Assignment__c records to create based on fee preference.');
            }

        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage() + ' ' + e.getLineNumber());
        }

        return;
    }

}