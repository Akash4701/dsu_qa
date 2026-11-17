import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";

import getStudents from "@salesforce/apex/HallTicketService.getStudents";
import generateHallTickets from "@salesforce/apex/HallTicketService.generateHallTickets";

const COLUMNS = [
  { label: "Student Roll Number", fieldName: "rollNo", type: "text" },
  { label: "Student Name", fieldName: "name", type: "text" },
  { label: "Email", fieldName: "email", type: "email" },
  { label: "Phone", fieldName: "phone", type: "phone" }
];

export default class HallTicketGenerator extends LightningElement {
  _recordId;

  @track students = [];
  @track selectedContactIds = [];

  isLoading = true;
  isInitialized = false;
  showAction = false;
  searchKeyword = "";

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    if (value && value !== this._recordId) {
      this._recordId = value;
      this.loadStudents(); // ✅ call apex only when recordId is ready
    }
  }

  get columns() {
    return COLUMNS;
  }

  get filteredStudents() {
    if (!this.searchKeyword) return this.students;
    const k = this.searchKeyword.toLowerCase();
    return this.students.filter((r) =>
      (r.name || "").toLowerCase().includes(k) ||
      (r.rollNo || "").toLowerCase().includes(k) ||
      (r.email || "").toLowerCase().includes(k)
    );
  }

  get filteredSelected() {
    const visible = new Set(this.filteredStudents.map(r => r.contactId));
    return this.selectedContactIds.filter(id => visible.has(id));
  }

  get disableGenerate() {
    return this.isLoading || !this.selectedContactIds.length;
  }

  handleSearch(event) {
    this.searchKeyword = event.target.value || "";
  }

  handleRowSelection(event) {
    const selectedRows = event.detail.selectedRows || [];
    this.selectedContactIds = selectedRows.map(r => r.contactId);
  }

  async loadStudents() {
    this.isLoading = true;
    this.isInitialized = true;

    try {
      const rows = await getStudents({ examCycleId: this.recordId });

      this.students = rows || [];
      this.showAction = true;
      this.isLoading = false;

      if (!this.students.length) {
        this.showToast("Error", "No eligible students found.", "error");
      }
    } catch (e) {
      this.isLoading = false;
      this.showToast("Error", this.getErrorMessage(e), "error");
      this.showAction = false;
      this.closeQuickAction();
    }
  }

  async handleGenerate() {
    this.isLoading = true;
    try {
      await generateHallTickets({
        examCycleId: this.recordId,
        contactIds: this.selectedContactIds
      });

      this.isLoading = false;
      this.showToast("Success", "Hall ticket generation started.", "success");
      this.closeQuickAction();
    } catch (e) {
      this.isLoading = false;
      this.showToast("Error", this.getErrorMessage(e), "error");
    }
  }

  handleCancel() {
    this.closeQuickAction();
  }

  closeQuickAction() {
    this.reset();
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  reset() {
    this.isInitialized = false;
    this.students = [];
    this.selectedContactIds = [];
    this.searchKeyword = "";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  getErrorMessage(e) {
    return e?.body?.message || e?.message || "Unknown error";
  }
}