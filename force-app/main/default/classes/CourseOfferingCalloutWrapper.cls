public class CourseOfferingCalloutWrapper {
    public String Name;
    public String Code;
    public String Path = '';
    public String CourseTemplateId;
    public String SemesterId = null;
    public String StartDate = null;
    public String EndDate = null;
    public String LocaleId = null;
    public Boolean ForceLocale = false;
    public Boolean ShowAddressBook = false;
    public Boolean CanSelfRegister = false;
    public DescriptionWrapper Description = new DescriptionWrapper();

    public class DescriptionWrapper {
        public String Content = 'This is a new Course Offering';
        public String Type = 'Text';
    }

    public CourseOfferingCalloutWrapper(String name, String code, String templateId) {
        this.Name = name;
        this.Code = code;
        this.CourseTemplateId = templateId;
    }
}