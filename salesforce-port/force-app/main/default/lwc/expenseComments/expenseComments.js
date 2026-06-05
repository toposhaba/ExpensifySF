import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import getCommentsForExpense from '@salesforce/apex/CommentService.getCommentsForExpense';
import getCommentsForReport from '@salesforce/apex/CommentService.getCommentsForReport';
import addComment from '@salesforce/apex/CommentService.addComment';
import deleteComment from '@salesforce/apex/CommentService.deleteComment';

export default class ExpenseComments extends LightningElement {
    @api recordId;
    @api objectApiName;

    comments = [];
    newComment = '';
    isLoading = false;
    currentUserId = USER_ID;

    connectedCallback() {
        this.loadComments();
    }

    get isReport() {
        return this.objectApiName === 'Expense_Report__c';
    }

    get isExpense() {
        return this.objectApiName === 'Expense__c';
    }

    get canAddComment() {
        return this.isExpense;
    }

    get hasComments() {
        return this.comments && this.comments.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasComments;
    }

    get isPostDisabled() {
        return this.isLoading || !this.newComment || this.newComment.trim().length === 0;
    }

    async loadComments() {
        if (!this.recordId) {
            return;
        }
        this.isLoading = true;
        try {
            const data = this.isReport
                ? await getCommentsForReport({ reportId: this.recordId })
                : await getCommentsForExpense({ expenseId: this.recordId });
            this.comments = data.map((row) => ({
                id: row.Id,
                body: row.Body__c,
                authorName: row.Author__r ? row.Author__r.Name : 'Unknown',
                createdDate: row.CreatedDate,
                canDelete: row.Author__c === this.currentUserId
            }));
        } catch (error) {
            this.showError(this.reduceError(error));
        } finally {
            this.isLoading = false;
        }
    }

    handleCommentChange(event) {
        this.newComment = event.target.value;
    }

    async handlePost() {
        if (this.isPostDisabled) {
            return;
        }
        this.isLoading = true;
        try {
            await addComment({ parentId: this.recordId, body: this.newComment });
            this.newComment = '';
            this.showSuccess('Comment added');
            await this.loadComments();
        } catch (error) {
            this.showError(this.reduceError(error));
            this.isLoading = false;
        }
    }

    async handleDelete(event) {
        const commentId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteComment({ commentId });
            this.showSuccess('Comment deleted');
            await this.loadComments();
        } catch (error) {
            this.showError(this.reduceError(error));
            this.isLoading = false;
        }
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred';
    }
}
