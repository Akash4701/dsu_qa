import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getGradeSettingCounts from '@salesforce/apex/GradeDistrubutionController.getGradeSettingCounts';
import updateGradeLowerBound from '@salesforce/apex/GradeDistrubutionController.updateGradeLowerBound';

export default class GradeDistribution extends LightningElement {
    recordId;
    isLoading = false;
    currentPageReference = null;
    gradeResult;
    totalNumberOfStudents;
    section = false;
    statistics;

    @track gradeSpreadRaw = [];
    @track consolidatedGradeMod = [];
    @track gradeData;

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.c__recordId || null;
            if (this.recordId) {
                this.gradeMod(this.recordId);
            }
        }
    }

    connectedCallback() {
        window.addEventListener('beforeprint', this.handleBeforePrint.bind(this));
        window.addEventListener('afterprint', this.handleAfterPrint.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('beforeprint', this.handleBeforePrint);
        window.removeEventListener('afterprint', this.handleAfterPrint);
    }

    handleBeforePrint() {
        if (this.chart) {
            this.chart.resize(900, 300);
            this.chart.update();
        }
    }

    handleAfterPrint() {
        if (this.chart) {
            this.chart.resize();
            this.chart.update();
        }
    }

    async gradeMod(courseOfferingId) {
        this.isLoading = true;

        try {
            this.gradeResult = await getGradeSettingCounts({ recordId: courseOfferingId });
            this.gradeData = this.gradeResult;

            const enrolments = this.gradeResult?.enrolments || [];
            this.totalNumberOfStudents = enrolments.length;

            if (this.gradeResult?.courseDetail?.gradeSchemeType === 'Course_Section') {
                this.section = true;
            }

            const gradeCounts = {};
            const consolidatedGradeCounts = {};

            if (enrolments.length > 0) {
                this.statistics = this.getStatistics(enrolments);

                // ---------- LOWER BOUND SAVE LOGIC ----------
                let valueToSave = null;

                const mechanismRaw = this.gradeResult.courseDetail?.mechanism || '';
                const mechanism = mechanismRaw.toLowerCase();
                const isAbsolute = mechanism.includes('absolute');

                console.log('Mechanism raw:', mechanismRaw, 'normalized:', mechanism, 'isAbsolute:', isAbsolute);
                console.log('gradeRanges:', JSON.stringify(this.gradeResult.gradeRanges));

                if (isAbsolute) {
                    // Absolute grading -> use F grade rangeEnd
                    const fGradeRow = (this.gradeResult.gradeRanges || []).find(row =>
                        (row.grade || row.letterGrade || '').toUpperCase() === 'F'
                    );
                    console.log('F grade row:', JSON.stringify(fGradeRow));

                    if (fGradeRow && fGradeRow.rangeEnd != null && fGradeRow.rangeEnd !== '') {
                        valueToSave = Number(fGradeRow.rangeEnd);
                    } else {
                        console.warn('No valid F grade rangeEnd found, will fall back to Mean-2SD');
                    }
                }

                // If not Absolute or F row missing, use Mean-2SD
                if (valueToSave === null) {
                    const mean2sd = this.statistics['Mean_-_(2x_Standard_Deviation)'];
                    console.log('Mean-2SD from stats:', mean2sd);
                    valueToSave = Number(mean2sd.toFixed(0));
                }

                console.log('Final lowerBoundValue to Apex:', valueToSave);

                if (valueToSave !== null && valueToSave !== undefined && !Number.isNaN(valueToSave)) {
                    await updateGradeLowerBound({
                        recordId: courseOfferingId,
                        lowerBoundValue: valueToSave,
                        mechanism: mechanismRaw
                    });
                }
                // ---------- END LOWER BOUND LOGIC ----------

                // Build grade spread data
                enrolments.forEach(item => {
                    let letterGrade = item.grade;

                    if (letterGrade) {
                        gradeCounts[letterGrade] = (gradeCounts[letterGrade] || 0) + 1;
                    }

                    const groups = {
                        A: ['A+', 'A'],
                        B: ['B+', 'B'],
                        C: ['C'],
                        P: ['P'],
                        F: ['F']
                    };

                    let consolidatedKey = null;
                    for (let group in groups) {
                        if (groups[group].includes(letterGrade)) {
                            consolidatedKey = group;
                            break;
                        }
                    }

                    if (consolidatedKey) {
                        consolidatedGradeCounts[consolidatedKey] =
                            (consolidatedGradeCounts[consolidatedKey] || 0) + 1;
                    }
                });

                const totalEnrolments = enrolments.length;
                const gradeOrder = ['A+', 'A','B+','B','C','P','F'];

                this.gradeSpreadRaw = gradeOrder.map(g => ({
                    key: g,
                    count: gradeCounts[g] || 0,
                    percentage: ((gradeCounts[g] || 0) / totalEnrolments * 100).toFixed(2)
                }));

                const consolidatedOrder = ['A', 'B', 'C', 'P', 'F'];

                this.consolidatedGradeMod = consolidatedOrder.map(g => ({
                    key: g,
                    count: consolidatedGradeCounts[g] || 0,
                    percentage: ((consolidatedGradeCounts[g] || 0) / totalEnrolments * 100).toFixed(2)
                }));
            }
        } catch (error) {
            console.error('Error in gradeMod:', error);
        } finally {
            this.isLoading = false;
        }
    }

    getStatistics(courseConnectionList) {
        try {
            const stats = {
                Mean: 0,
                Median: 0,
                Standard_Deviation: 0,
                Minimum: 0,
                Maximum: 0,
                Range: 0
            };

            if (!courseConnectionList) return stats;

            const validScores = courseConnectionList.filter(
                item => item?.componentFinalScore != null
            );

            const numberOfStudents = validScores.length;
            if (numberOfStudents === 0) return stats;

            const sortedScores = validScores
                .map(item => item.componentFinalScore)
                .sort((a, b) => a - b);

            let totalMarks = sortedScores.reduce((sum, v) => sum + v, 0);
            stats.Mean = totalMarks / numberOfStudents;

            let variance = sortedScores.reduce((sum, score) => {
                return sum + Math.pow(stats.Mean - score, 2);
            }, 0);

            stats.Standard_Deviation = Math.sqrt(variance / (numberOfStudents - 1));

            if (numberOfStudents % 2 === 1) {
                stats.Median = sortedScores[(numberOfStudents - 1) / 2];
            } else {
                let mid = numberOfStudents / 2;
                stats.Median = (sortedScores[mid] + sortedScores[mid - 1]) / 2;
            }

            stats.Minimum = sortedScores[0];
            stats.Maximum = sortedScores[sortedScores.length - 1];
            stats.Range = stats.Maximum - stats.Minimum;

            stats['Mean_-_(2x_Standard_Deviation)'] =
                stats.Mean - 2 * stats.Standard_Deviation;

            return stats;
        } catch (e) {
            throw new Error(e.message);
        }
    }

    get isGradeChartLoaded() {
        return this.gradeSpreadRaw.length > 0;
    }

    get isStatisticsLoaded() {
        return this.statistics;
    }

    handleRefresh() {
        this.gradeMod(this.recordId);
    }
}