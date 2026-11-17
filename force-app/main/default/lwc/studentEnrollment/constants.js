// const COLUMNS = [
//     { label: 'Student Name', fieldName: 'studentName' },
//      { label: 'Student Code', fieldName: 'studentCode' },
//     { label: 'Student Email', fieldName: 'studentEmail' },
//     { label: 'Student Phone', fieldName: 'studentPhone' },
   
// ];

// const COURSE_OFFERING_COLUMNS = [{ label: 'Course Offering Name', fieldName: 'courseOfferingName' }];

// export { COLUMNS, COURSE_OFFERING_COLUMNS };

export const COLUMNS = [
    // {
    //     label: 'Student Code',
    //     fieldName: 'studentCode',
    //     type: 'text',
    // },
    {
        label: 'Name',
        fieldName: 'studentName',
        type: 'text',
    },
    {
        label: 'USN Number',
        fieldName: 'studentCode',
        type: 'text',
    },
    {
        label: 'Email',
        fieldName: 'studentEmail',
        type: 'email',
    },
    {
        label: 'Phone',
        fieldName: 'studentPhone',
        type: 'phone',
    }
];

export const COURSE_OFFERING_COLUMNS = [
    {
        label: 'Course Name',
        fieldName: 'courseOfferingName',
        type: 'text',
    }
];