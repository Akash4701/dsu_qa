const COLUMNS =[
  {
  label: "Course Connection",
  fieldName: "courseConnectionUrl",
  type: "url",
  sortable: true,
  typeAttributes: {
    label: { fieldName: "courseConnectionName" },
    target: "_blank"
  }
},
  {
    label: "Roll No",
    fieldName: "rollNo",
    editable: false,
    cellAttributes: { alignment: "left" }
  },
  {
    label: "Composite Marks",
    fieldName: "markObtained",
    editable: false,
    sortable: true,
    cellAttributes: { alignment: "left" }
  },
  {
    label: "Letter Grade",
    fieldName: "grade",
    editable: false,
    sortable: true,
    cellAttributes: { alignment: "left" }
  },
  {
    label: "Override Grade",
    fieldName: "overrideGrade",
    editable: true,
    type: "picklistColumn",
    cellAttributes: { alignment: "left" },
    typeAttributes: {
      placeholder: "Choose Override Grade",
      options: { fieldName: "overridePicklistOption" },
      value: { fieldName: "overrideGrade" },
      context: { fieldName: "id" }
    }
  },
  {
    label: "Final Grade",
    fieldName: "finalGrade",
    editable: false,
    sortable: true,
    cellAttributes: { alignment: "left" }
  },
  {
    label: "Reason for Downgrade",
    fieldName: "reasonForDownFall",
    editable: true,
    type: "picklistColumn",
    cellAttributes: { alignment: "left" },
    typeAttributes: {
      placeholder: "Choose reason for downfall",
      options: { fieldName: "definitionPicklistOption" },
      value: { fieldName: "reasonForDownFall" },
      context: { fieldName: "id" }
    }
  },
  {
    label: "Comment",
    fieldName: "comment",
    editable: true,
    cellAttributes: { alignment: "left" }
  }
];

export { COLUMNS };