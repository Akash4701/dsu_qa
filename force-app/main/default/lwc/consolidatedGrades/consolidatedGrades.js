import { LightningElement, api, track } from "lwc";
import { COLUMNS } from "./constants";

export default class ConsolidatedGrades extends LightningElement {
    @track _childProperty;

    table1Data = [];
    table1Columns = COLUMNS;

    isPrint = false;

    consolidatedBuckets = {
        A: ["A+", "A"],
        B: ["B+", "B"],
        C: ["C"],
        P: ["P"],
        F: ["F"]
    };

    connectedCallback() {
        this._beforePrint = () => { this.isPrint = true; };
        this._afterPrint = () => { this.isPrint = false; };

        window.addEventListener("beforeprint", this._beforePrint);
        window.addEventListener("afterprint", this._afterPrint);
    }

    disconnectedCallback() {
        window.removeEventListener("beforeprint", this._beforePrint);
        window.removeEventListener("afterprint", this._afterPrint);
    }

    @api
    get childProperty() {
        return this._childProperty;
    }

    set childProperty(value) {
        if (!value) return;

        this._childProperty = value;

        const isAlreadyConsolidated = value.every(item =>
            ["A", "B", "C", "P", "F"].includes(item.key)
        );

        if (isAlreadyConsolidated) {
            this.table1Data = value.map((item, index) => ({
                id: index.toString(),
                Letter_Grade__c: item.key,
                countStudent: item.count,
                percentage: item.percentage
            }));
        } else {
            this.table1Data = value.map((item, index) => ({
                id: index.toString(),
                Letter_Grade__c: item.key,
                countStudent: item.count,
                percentage: item.percentage
            }));
        }
    }

    generateConsolidatedData(gradeSpread) {
        let result = { A: 0, B: 0, C: 0, D: 0, F: 0 };
        let totalStudents = 0;

        gradeSpread.forEach(item => {
            let letter = item.key;
            let count = item.count || 0;
            totalStudents += count;

            for (let bucket in this.consolidatedBuckets) {
                if (this.consolidatedBuckets[bucket].includes(letter)) {
                    result[bucket] += count;
                }
            }
        });

        this.table1Data = Object.keys(result).map((grade, index) => ({
            id: index.toString(),
            Letter_Grade__c: grade,
            countStudent: result[grade],
            percentage:
                totalStudents > 0
                    ? ((result[grade] / totalStudents) * 100).toFixed(2)
                    : "0.00"
        }));
    }
}