import { LightningElement, api } from "lwc";

export default class CustomCard extends LightningElement {
  @api cardClass;
  @api statistics;
  @api marks;
}