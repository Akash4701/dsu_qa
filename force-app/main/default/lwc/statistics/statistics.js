import { LightningElement, api, track } from "lwc";

export default class Statistics extends LightningElement {
    @track _childProperty;
    cardsData = [];

    @api
    get childProperty() {
        return this._childProperty;
    }

    set childProperty(value) {
        if (!value) return;
        this._childProperty = value;

        this.cardsData = Object.entries(value).map((el, index) => ({
            id: index,
            statistics: el[0].replaceAll("_", " "),
            marks: isNaN(el[1]) ? "N/A" : Number(el[1]).toFixed(2)
        }));
    }
}