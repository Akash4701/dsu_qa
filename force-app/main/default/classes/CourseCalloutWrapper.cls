public class CourseCalloutWrapper {
    public List<CourseData> courses;

    public class CourseData {
        public String Name;
        public String Code;
        public String Path;
        public List<String> ParentOrgUnitIds;

        public CourseData(String name, String code, String parentOrgUnitId) {
            this.Name = name;
            this.Code = code;
            this.Path = '';
            this.ParentOrgUnitIds = new List<String>{parentOrgUnitId};
        }
    }
}