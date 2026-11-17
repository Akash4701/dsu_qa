/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 11-20-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public class RequestWrapper {
	public MainWrapper wrapper;
	public List<FacilitiesWrapper> facilities;
	public List<ExamConnectionsWrapper> examConnections;
	public List<FacilityBookingWrapper> facilityBookings;
	public List<SectionsWrapper> sections;
	public AccountWrapper programs;
	public List<BatchWrapper> batches;
	public List<TermWrapper> terms;
	public List<CourseWrapper> courses;
	public List<EvaluatorWrapper> evaluators;
	public List<ExamWrapper> exams;

	public interface API {
		SObject getRecord();
	}

	public class MainWrapper {
		public Integer eligibelStudents;
		public List<FacilitiesWrapper> facilities;
		public List<ExamConnectionsWrapper> examConnections;
		public List<ExamConnectionsWrapper> otherExamRelatedExamConnections;

		public mainWrapper(
			Integer noOfStudents,
			List<FacilitiesWrapper> facilityList,
			List<Exam_Connections__c> examConnections,
			List<Exam_Connections__c> otherExamRelatedExamConnections
		) {
			this.eligibelStudents = noOfStudents;
			this.facilities = facilityList;
			this.examConnections = new List<ExamConnectionsWrapper>();
			this.otherExamRelatedExamConnections = new List<ExamConnectionsWrapper>();

			if (examConnections != null) {
				for (Exam_Connections__c examConnObj : examConnections) {
					this.examConnections.add(new ExamConnectionsWrapper(examConnObj));
				}
			}
			if (otherExamRelatedExamConnections != null) {
				for (Exam_Connections__c examConnObj : otherExamRelatedExamConnections) {
					this.otherExamRelatedExamConnections.add(new ExamConnectionsWrapper(examConnObj));
				}
			}
		}
	}

	public class ExamConnectionsWrapper implements RequestWrapper.API {
		public Id examConnectionRecordId;
		public Id studentRecordId;
		public String studentName;
		public String rollNumber;
		public Id courseConnectionId;
		public Id facilityId;
		public String facilityName;
		public Decimal seatNumber;
		public Decimal columnNumber;
		public Decimal rowNumber;

		public ExamConnectionsWrapper(Exam_Connections__c exmConetObj) {
			this.examConnectionRecordId = exmConetObj.Id;
			this.studentRecordId = exmConetObj.Student_Name__r.Id;
			this.studentName = exmConetObj.Student_Name__r.Name;
			this.rollNumber = exmConetObj.Student_Roll_Number__c;
		}

		public Exam_Connections__c getRecord() {
			Exam_Connections__c examConnectionObj = new Exam_Connections__c();

			examConnectionObj.Id = this.examConnectionRecordId;
			if (this.studentRecordId != null) {
				examConnectionObj.Student_Name__c = this.studentRecordId;
			}
			if (this.courseConnectionId != null) {
				examConnectionObj.Course_Connection_ID__c = this.courseConnectionId;
			}
			if (this.seatNumber != null) {
				examConnectionObj.Seat_Number__c = this.seatNumber;
			}

			return examConnectionObj;
		}
	}

	public class FacilitiesWrapper {
		public Id facilityId;
		public String facilityName;
		public Id facilityBookingRecordId;
		public Decimal noOfInvigilators;
		public Decimal effectiveCapacity;
		public Decimal noOfColumns;
		public Decimal noOfRows;
		public String seatsPerBench;
		public Boolean chosen;
		public Decimal intercandidateSpacing;
	}

	public class SectionsWrapper {
		public Id courseOfferingId;
		public String section;
		public Id courseOfferingExamConnectionId;
	}

	public class FacilityBookingWrapper implements RequestWrapper.API {
		public Id facilityBookingRecordId;
		public DateTime bookedStartDateTime;
		public DateTime bookedEndDateTime;
		public Id examId;
		public Id facilityId;
		public Id bookedByContactId;
		public Decimal bookedCapacity;
		public Decimal noOfInvigilators;
		public Decimal intercandidateSpacing;

		public Facility_Booking__c getRecord() {
			Facility_Booking__c facBookingObj = new Facility_Booking__c();

			if (this.facilityBookingRecordId != null) {
				facBookingObj.Id = facilityBookingRecordId;
			}
			if (this.bookedStartDateTime != null) {
				facBookingObj.Start_Date_and_Time__c = (bookedStartDateTime + 0.2290);
			}
			if (this.bookedEndDateTime != null) {
				facBookingObj.End_Date_and_Time__c = (bookedEndDateTime + 0.2290);
			}
			if (this.examId != null) {
				facBookingObj.Exam__c = examId;
			}
			if (this.facilityId != null) {
				facBookingObj.FacilityID__c = facilityId;
			}
			if (this.noOfInvigilators != null) {
				facBookingObj.Number_Of_Invigilators_Required__c = noOfInvigilators;
			}
			if (this.intercandidateSpacing != null) {
				facBookingObj.Inter_Candidate_Spacing__c = intercandidateSpacing;
			}

			return facBookingObj;
		}
	}

	public class EvaluatorWrapper implements RequestWrapper.API {
		public Id evaluatorId;
		public Id examId;
		public Id courseOfferingId;
		public String section;
		public Id contactId;
		public String contcatName;
		public String contcatRole;
		public String contactEmail;
		public String status;
		public String reason;

		public EvaluatorWrapper(Evaluation__c evaluatorRecord) {
			this.evaluatorId = evaluatorRecord.Id;
			this.examId = evaluatorRecord.Exam_ID__c;
			this.courseOfferingId = evaluatorRecord.Course_Offering__c;
			this.section = evaluatorRecord.Course_Offering__r.hed__Section_ID__c;
			this.contactId = evaluatorRecord.Contact__c;
			this.contcatName = evaluatorRecord.Contact__r.Name;
			this.contactEmail = evaluatorRecord.Contact__r.Email;
			this.status = evaluatorRecord.Evaluator_Acceptance_Status__c;
			this.reason = evaluatorRecord.Reason_For_Rejection__c;
		}

		public Evaluation__c getRecord() {
			Evaluation__c evalObj = new Evaluation__c();
			if (this.evaluatorId != null) {
				evalObj.Id = this.evaluatorId;
			}
			if (this.examId != null) {
				evalObj.Exam_ID__c = this.examId;
			}
			if (this.contactId != null) {
				evalObj.Contact__c = this.contactId;
			}
			if (this.status != null) {
				evalObj.Evaluator_Acceptance_Status__c = this.status;
			}
			if (this.reason != null) {
				evalObj.Reason_For_Rejection__c = this.reason;
			}

			return evalObj;
		}
	}

	public class AccountWrapper {
		public Id accountId;
		public String accountName;
		public List<BatchWrapper> batches;

		public AccountWrapper(Account acc, List<hed__Program_Plan__c> prgPlans) {
			this.accountId = acc.Id;
			this.accountName = acc.Name;
			this.batches = new List<BatchWrapper>();

			if (prgPlans != null) {
				for (hed__Program_Plan__c prgPlanObj : prgPlans) {
					this.batches.add(new BatchWrapper(prgPlanObj, prgPlanObj.Terms__r));
				}
			}
		}
	}
	public class BatchWrapper {
		public Id programPlanId;
		public String programPlanName;
		public List<TermWrapper> terms;

		public BatchWrapper(hed__Program_Plan__c prgPlan, List<hed__Term__c> term) {
			this.programPlanId = prgPlan.Id;
			this.programPlanName = prgPlan.Name;
			this.terms = new List<TermWrapper>();
			for (hed__Term__c termObj : term) {
				this.terms.add(new TermWrapper(termObj));
			}
		}
	}
	public class TermWrapper {
		public Id termId;
		public String termName;
		//public List<CourseWrapper> courses;

		public TermWrapper(hed__Term__c term) {
			this.termId = term.Id;
			this.termName = term.Name;
			//this.
		}
	}

	public class CourseWrapper {
		public Id courseOfferingId;
		public String courseName;
		public String section;

		public CourseWrapper(hed__Course_Offering__c couOfferingObj) {
			this.courseOfferingId = couOfferingObj.Id;
			this.courseName = couOfferingObj.hed__Course__r.Name;
			this.section = couOfferingObj.hed__Section_ID__c;
		}
	}

	public class ExamWrapper {
		public Id examRecordId;
		public Date examDate;
		public Time startTime;
		public Time endTime;
		public String programName;
		public String termName;
		public String courseName;
		public String examName;
		public String examType;
		public Date dueDate;
		public String approvalStatus;
		public String examFormat;
		public String examPattern;
		public String examMode;
		public String courseCode;
		public List<String> sections;

		public ExamWrapper() {
		}

		public void getRecord() {
		}
	}

}