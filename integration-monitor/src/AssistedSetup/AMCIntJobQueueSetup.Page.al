namespace Addmecode.IntegrationMonitor.AssistedSetup;

using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Outbox;
using System.Threading;

page 50107 "AMC Int. Job Queue Setup"
{
    PageType = NavigatePage;
    ApplicationArea = All;
    Caption = 'Integration Monitor Job Queue Setup';
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            group(OutboxDispatcher)
            {
                Caption = 'Outbox Dispatcher';
                Visible = this.OutboxStepVisible;

                field(SetupOutboxDispatcher; this.SetupOutboxDispatcher)
                {
                    ApplicationArea = All;
                    CaptionClass = this.GetOutboxDispatcherCaption();
                    ToolTip = 'Specifies whether to create or update the recurring job queue entry for processing outbound integration messages.';
                }
                field(OutboxIntervalInMinutes; this.OutboxIntervalInMinutes)
                {
                    ApplicationArea = All;
                    Caption = 'Outbox interval (minutes)';
                    MinValue = 1;
                    ToolTip = 'Specifies how many minutes should pass between outbox dispatcher runs.';
                }
                field(OutboxJobQueueCategoryCode; this.OutboxJobQueueCategoryCode)
                {
                    ApplicationArea = All;
                    Caption = 'Outbox job queue category code';
                    TableRelation = "Job Queue Category".Code;
                    ToolTip = 'Specifies the job queue category code for the outbox dispatcher job queue entry.';
                }
            }

            group(InboxDispatcher)
            {
                Caption = 'Inbox Dispatcher';
                Visible = this.InboxStepVisible;

                field(SetupInboxDispatcher; this.SetupInboxDispatcher)
                {
                    ApplicationArea = All;
                    CaptionClass = this.GetInboxDispatcherCaption();
                    ToolTip = 'Specifies whether to create or update the recurring job queue entry for processing inbound integration responses.';
                }
                field(InboxIntervalInMinutes; this.InboxIntervalInMinutes)
                {
                    ApplicationArea = All;
                    Caption = 'Inbox interval (minutes)';
                    MinValue = 1;
                    ToolTip = 'Specifies how many minutes should pass between inbox dispatcher runs.';
                }
                field(InboxJobQueueCategoryCode; this.InboxJobQueueCategoryCode)
                {
                    ApplicationArea = All;
                    Caption = 'Inbox job queue category code';
                    TableRelation = "Job Queue Category".Code;
                    ToolTip = 'Specifies the job queue category code for the inbox dispatcher job queue entry.';
                }
            }

            group(CleanupDispatcher)
            {
                Caption = 'Cleanup Dispatcher';
                Visible = this.CleanupStepVisible;

                field(SetupCleanupDispatcher; this.SetupCleanupDispatcher)
                {
                    ApplicationArea = All;
                    CaptionClass = this.GetCleanupDispatcherCaption();
                    ToolTip = 'Specifies whether to create or update the recurring job queue entry for deleting old completed or cancelled outbox entries.';
                }
                field(CleanupIntervalInMinutes; this.CleanupIntervalInMinutes)
                {
                    ApplicationArea = All;
                    Caption = 'Cleanup interval (minutes)';
                    MinValue = 1;
                    ToolTip = 'Specifies how many minutes should pass between cleanup dispatcher runs.';
                }
                field(CleanupJobQueueCategoryCode; this.CleanupJobQueueCategoryCode)
                {
                    ApplicationArea = All;
                    Caption = 'Cleanup job queue category code';
                    TableRelation = "Job Queue Category".Code;
                    ToolTip = 'Specifies the job queue category code for the cleanup dispatcher job queue entry.';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ShowJobQueueEntry)
            {
                ApplicationArea = All;
                Caption = 'Show Job Queue Entry';
                Enabled = this.ShowJobQueueEntryEnabled;
                Image = Job;
                InFooterBar = true;
                ToolTip = 'Opens the existing job queue entry for the current dispatcher.';

                trigger OnAction()
                begin
                    this.ShowCurrentJobQueueEntry();
                end;
            }
            action(Back)
            {
                ApplicationArea = All;
                Caption = 'Back';
                Enabled = this.BackEnabled;
                Image = PreviousRecord;
                InFooterBar = true;
                ToolTip = 'Goes back to the previous dispatcher setup step.';

                trigger OnAction()
                begin
                    this.GoBack();
                end;
            }
            action("Next")
            {
                ApplicationArea = All;
                Caption = 'Next';
                Enabled = this.NextEnabled;
                Image = NextRecord;
                InFooterBar = true;
                ToolTip = 'Continues to the next dispatcher setup step.';

                trigger OnAction()
                begin
                    this.GoNext();
                end;
            }
            action(Finish)
            {
                ApplicationArea = All;
                Caption = 'Finish';
                Enabled = this.FinishEnabled;
                Image = Approve;
                InFooterBar = true;
                ToolTip = 'Creates or updates the selected Integration Monitor job queue entries.';

                trigger OnAction()
                begin
                    this.FinishSetup();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.InitializePage();
    end;

    local procedure InitializePage()
    begin
        this.SetDefaults();
        this.SetStep(this.GetOutboxStepNo());
    end;

    local procedure SetDefaults()
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        JobQueueSetupMgt.SetOutboxDispatcherDefaults(this.OutboxDispatcherExists, this.SetupOutboxDispatcher, this.OutboxIntervalInMinutes, this.OutboxJobQueueCategoryCode);
        JobQueueSetupMgt.SetInboxDispatcherDefaults(this.InboxDispatcherExists, this.SetupInboxDispatcher, this.InboxIntervalInMinutes, this.InboxJobQueueCategoryCode);
        JobQueueSetupMgt.SetCleanupDispatcherDefaults(this.CleanupDispatcherExists, this.SetupCleanupDispatcher, this.CleanupIntervalInMinutes, this.CleanupJobQueueCategoryCode);
    end;

    local procedure SetStep(NewStep: Integer)
    begin
        this.CurrentStep := NewStep;
        this.OutboxStepVisible := this.CurrentStep = this.GetOutboxStepNo();
        this.InboxStepVisible := this.CurrentStep = this.GetInboxStepNo();
        this.CleanupStepVisible := this.CurrentStep = this.GetCleanupStepNo();
        this.BackEnabled := this.CurrentStep > this.GetOutboxStepNo();
        this.NextEnabled := this.CurrentStep < this.GetCleanupStepNo();
        this.FinishEnabled := this.CurrentStep = this.GetCleanupStepNo();
        this.ShowJobQueueEntryEnabled := this.GetCurrentDispatcherExists();
    end;

    local procedure GetCurrentDispatcherExists(): Boolean
    begin
        case this.CurrentStep of
            this.GetOutboxStepNo():
                exit(this.OutboxDispatcherExists);
            this.GetInboxStepNo():
                exit(this.InboxDispatcherExists);
            this.GetCleanupStepNo():
                exit(this.CleanupDispatcherExists);
        end;
    end;

    local procedure ShowCurrentJobQueueEntry()
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        case this.CurrentStep of
            this.GetOutboxStepNo():
                JobQueueSetupMgt.ShowOutboxJobQueueEntry();
            this.GetInboxStepNo():
                JobQueueSetupMgt.ShowInboxJobQueueEntry();
            this.GetCleanupStepNo():
                JobQueueSetupMgt.ShowCleanupJobQueueEntry();
        end;
    end;

    local procedure GoBack()
    begin
        if this.CurrentStep <= this.GetOutboxStepNo() then
            exit;

        this.SetStep(this.CurrentStep - 1);
        CurrPage.Update(false);
    end;

    local procedure GoNext()
    begin
        if this.CurrentStep >= this.GetCleanupStepNo() then
            exit;

        this.SetStep(this.CurrentStep + 1);
        CurrPage.Update(false);
    end;

    local procedure FinishSetup()
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        this.SetupDispatcherJobs(JobQueueSetupMgt);
        JobQueueSetupMgt.CompleteAssistedSetup();
        CurrPage.Close();
    end;

    local procedure SetupDispatcherJobs(var JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.")
    begin
        if this.SetupOutboxDispatcher then
            JobQueueSetupMgt.SetupOutboxDispatcherJob(this.OutboxIntervalInMinutes, this.OutboxJobQueueCategoryCode);

        if this.SetupInboxDispatcher then
            JobQueueSetupMgt.SetupInboxDispatcherJob(this.InboxIntervalInMinutes, this.InboxJobQueueCategoryCode);

        if this.SetupCleanupDispatcher then
            JobQueueSetupMgt.SetupCleanupDispatcherJob(this.CleanupIntervalInMinutes, this.CleanupJobQueueCategoryCode);
    end;

    local procedure GetOutboxDispatcherCaption(): Text
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        exit(JobQueueSetupMgt.GetOutboxDispatcherCaption(this.OutboxDispatcherExists));
    end;

    local procedure GetInboxDispatcherCaption(): Text
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        exit(JobQueueSetupMgt.GetInboxDispatcherCaption(this.InboxDispatcherExists));
    end;

    local procedure GetCleanupDispatcherCaption(): Text
    var
        JobQueueSetupMgt: Codeunit "AMC Int. Job Queue Setup Mgt.";
    begin
        exit(JobQueueSetupMgt.GetCleanupDispatcherCaption(this.CleanupDispatcherExists));
    end;

    local procedure GetOutboxStepNo(): Integer
    begin
        exit(1);
    end;

    local procedure GetInboxStepNo(): Integer
    begin
        exit(2);
    end;

    local procedure GetCleanupStepNo(): Integer
    begin
        exit(3);
    end;

    var
        BackEnabled: Boolean;
        CleanupDispatcherExists: Boolean;
        CleanupIntervalInMinutes: Integer;
        CleanupJobQueueCategoryCode: Code[10];
        CleanupStepVisible: Boolean;
        CurrentStep: Integer;
        FinishEnabled: Boolean;
        InboxDispatcherExists: Boolean;
        InboxIntervalInMinutes: Integer;
        InboxJobQueueCategoryCode: Code[10];
        InboxStepVisible: Boolean;
        NextEnabled: Boolean;
        OutboxDispatcherExists: Boolean;
        OutboxIntervalInMinutes: Integer;
        OutboxJobQueueCategoryCode: Code[10];
        OutboxStepVisible: Boolean;
        SetupCleanupDispatcher: Boolean;
        SetupInboxDispatcher: Boolean;
        SetupOutboxDispatcher: Boolean;
        ShowJobQueueEntryEnabled: Boolean;
}
