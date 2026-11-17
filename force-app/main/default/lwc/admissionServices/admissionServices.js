// import { LightningElement, track } from 'lwc';
// import { LABEL } from './constants';

// export default class AdmissionServices extends LightningElement {
//     @track
//     state = {
//         showStudentEnrollment: false,
//         showFacultyEnrollment: false,
//         showTermEnrollment:false,
//     };
//     @track responseData = {};

//     get label() {
//         return LABEL;
//     }

//     get showButtons() {
//         const { showStudentEnrollment, showFacultyEnrollment,showTermEnrollment} = this.state;
//         return !(showStudentEnrollment || showFacultyEnrollment || showTermEnrollment);
//     }

//     get breadcrumbPath() {
//         const breadcrumb = [{ label: LABEL.home, id: '1' }];
//         const { showStudentEnrollment, showFacultyEnrollment,showTermEnrollment } = this.state;

//         if (showStudentEnrollment) {
//             breadcrumb.push({ label: LABEL.studentEnrollment, id: '2' });
//         }

//         if (showFacultyEnrollment) {
//             breadcrumb.push({ label: LABEL.facultyEnrollment, id: '3' });
//         }
//         if (showTermEnrollment) {
//             breadcrumb.push({ label: LABEL.termEnrollment, id: '4' });
//         }

//         return breadcrumb;
//     }

//     handleHomeClick() {
//         this.state = {
//             ...this.state,
//             showStudentEnrollment: false,
//             showFacultyEnrollment: false,
//             showTermEnrollment:false,
//         };
//     }

//     handleStudentEnrollmentClick() {
//         this.state.showStudentEnrollment = true;
//     }
//     handleTermEnrollmentClick() {
//         this.state.showTermEnrollment = true;
//     }

//     handleFacultyEnrollmentClick() {
//         this.state.showFacultyEnrollment = true;
//     }

//     handleCrumbClick(event) {
//         // prevent default navigation by href
//         event.preventDefault();

//         const name = event.target.name;

//         if (name == LABEL.home) {
//             this.handleHomeClick();
//         }
//     }
// }

// enrollmentTabs.js
import { LightningElement } from 'lwc';

export default class AdmissionServices extends LightningElement {
}