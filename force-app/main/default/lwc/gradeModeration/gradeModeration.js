import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/chartJS';

export default class GradeModeration extends LightningElement {
    @api get childProperty() {
        return this._childProperty();
    }

    Chartdata;

    set childProperty(value) {
        if (!value) return;

        this._childProperty = value;
        this.chartJsInitialized = true;
        loadScript(this, CHART_JS)
            .then(() => {
                console.log('Data', this.Chartdata);
                this.labelData = value.map((item) => item.key);
                this.data = value.map((item) => item.count);
                this.initializeLineChart();
            })
            .catch((error) => {
                console.log('Error loading Chart.js', error);
            });
    }

    @track chartJsInitialized = false;
    labelData = [];
    data = [];
    canvasRef = null;

    initializeLineChart() {
        if (typeof Chart === 'undefined') {
            console.error('Chart.js library not loaded.');
            return;
        }

        const data = {
            labels: this.labelData,
            datasets: [
                {
                    label: 'Normal Distribution',
                     barPercentage: 0.5,
                      barThickness: 3,
                      maxBarThickness: 3,
                      minBarLength: 2,
                      backgroundColor: "green",
                    data: this.data,
                },
            ],
        };

        const options = {
            responsive: true,
            maintainAspectRatio: false,
                layout: {
        padding: {
            top: 10,     
            bottom: 10,
            left: 10,
            right: 10
        }
    },

            scales: {
               yAxes: [
                {
                    ticks: {
                        beginAtZero: true, 
                        stepSize: 2, 
                         padding: 5  
                    },
                    scaleLabel: {
                        display: true,
                        labelString: 'No.of Students'
                    }
                }
            ],
              xAxes: [{
                ticks: {
            padding: 5     
        },
                scaleLabel: {
                  display: true,
                  labelString: 'Grades'
                },
                 gridLines: {
            display: true
        }
              }]
            },
        };

        const ctx = this.canvasRef.getContext('2d');
        new Chart(ctx, {
            type: 'bar',
            data: data,
            options: options,
        });
    }

    renderedCallback() {
        if (!this.canvasRef) {
            this.canvasRef = this.template.querySelector('canvas');
        }
    }
}