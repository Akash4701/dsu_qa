public class UserEnrollmentWrapper {
    public UserData user;
    public List<EnrollmentData> enroll;

    public UserEnrollmentWrapper() {
        this.user = new UserData();
        this.enroll = new List<EnrollmentData>();
    }

    public class UserData {
        public String OrgDefinedId;
        public String FirstName;
        public String MiddleName;
        public String LastName;
        public String ExternalEmail;
        public String UserName;
        public String RoleId;
        public String ProfileUrl;
        public Boolean IsActive;
        public Boolean SendCreationEmail;

        public UserData() {
            this.RoleId = '110';
            this.IsActive = true;
            this.SendCreationEmail = false;
        }

    }

    public class EnrollmentData {
        public String OrgSFID;
        public String OrgUnitId;
        public String UserId;
        public String RoleId;
        public Boolean IsCascading;

        public EnrollmentData() {
            this.UserId = '';
            this.RoleId = '110';
            this.IsCascading = false;
        }

        public Boolean equals(Object obj) {
            if (obj instanceof EnrollmentData) {
                EnrollmentData other = (EnrollmentData) obj;
                return this.OrgUnitId == other.OrgUnitId;
            }
            return false;
        }

        public Integer hashCode() {
            return (OrgSFID + OrgUnitId).hashCode();
        }

    }

    public class ApiResponse {
        public UserResponse user;
        public List<EnrollmentResponse> enroll;
    }

    public class UserResponse {
        public Boolean status;
        public String recordId;
        public String lmsId;
    }

    public class EnrollmentResponse {
        public Boolean status;
        public String recordId;
    }
}