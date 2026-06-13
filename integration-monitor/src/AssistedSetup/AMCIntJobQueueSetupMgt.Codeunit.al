namespace Addmecode.IntegrationMonitor.AssistedSetup;

using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Outbox;
using System.Environment.Configuration;
using System.Threading;

codeunit 50136 "AMC Int. Job Queue Setup Mgt."
{
    Permissions = tabledata "Job Queue Entry" = rimd;

    procedure SetOutboxDispatcherDefaults(var DispatcherExists: Boolean; var SetupDispatcher: Boolean; var IntervalInMinutes: Integer; var JobQueueCategoryCode: Code[10])
    begin
        this.SetDispatcherDefaults(DispatcherExists, SetupDispatcher, IntervalInMinutes, JobQueueCategoryCode, Codeunit::"AMC Outbox Dispatcher Job", this.GetDefaultOutboxIntervalInMinutes());
    end;

    procedure SetInboxDispatcherDefaults(var DispatcherExists: Boolean; var SetupDispatcher: Boolean; var IntervalInMinutes: Integer; var JobQueueCategoryCode: Code[10])
    begin
        this.SetDispatcherDefaults(DispatcherExists, SetupDispatcher, IntervalInMinutes, JobQueueCategoryCode, Codeunit::"AMC Inbox Dispatcher Job", this.GetDefaultInboxIntervalInMinutes());
    end;

    procedure SetCleanupDispatcherDefaults(var DispatcherExists: Boolean; var SetupDispatcher: Boolean; var IntervalInMinutes: Integer; var JobQueueCategoryCode: Code[10])
    begin
        this.SetDispatcherDefaults(DispatcherExists, SetupDispatcher, IntervalInMinutes, JobQueueCategoryCode, Codeunit::"AMC Outbox Cleanup Job", this.GetDefaultCleanupIntervalInMinutes());
    end;

    local procedure SetDispatcherDefaults(var DispatcherExists: Boolean; var SetupDispatcher: Boolean; var IntervalInMinutes: Integer; var JobQueueCategoryCode: Code[10]; CodeunitId: Integer; DefaultIntervalInMinutes: Integer)
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        DispatcherExists := this.GetDispatcherJob(CodeunitId, JobQueueEntry);
        SetupDispatcher := not DispatcherExists;
        if DispatcherExists then begin
            IntervalInMinutes := JobQueueEntry."No. of Minutes between Runs";
            JobQueueCategoryCode := JobQueueEntry."Job Queue Category Code";
            exit;
        end;

        IntervalInMinutes := DefaultIntervalInMinutes;
        Clear(JobQueueCategoryCode);
    end;

    procedure GetDispatcherJob(CodeunitId: Integer; var JobQueueEntry: Record "Job Queue Entry"): Boolean
    begin
        JobQueueEntry.Reset();
        this.SetDispatcherJobFilters(JobQueueEntry, CodeunitId);
        exit(JobQueueEntry.FindFirst());
    end;

    local procedure SetDispatcherJobFilters(var JobQueueEntry: Record "Job Queue Entry"; CodeunitId: Integer)
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", CodeunitId);
    end;

    procedure GetDefaultOutboxIntervalInMinutes(): Integer
    begin
        exit(5);
    end;

    procedure GetDefaultInboxIntervalInMinutes(): Integer
    begin
        exit(5);
    end;

    procedure GetDefaultCleanupIntervalInMinutes(): Integer
    begin
        exit(1440);
    end;

    procedure DispatcherJobExists(CodeunitId: Integer): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        exit(this.GetDispatcherJob(CodeunitId, JobQueueEntry));
    end;

    procedure GetOutboxDispatcherCaption(DispatcherExists: Boolean): Text
    var
        CreateOutboxDispatcherTxt: Label 'Create outbox dispatcher';
        UpdateOutboxDispatcherTxt: Label 'Update outbox dispatcher';
    begin
        exit(this.GetDispatcherCaption(DispatcherExists, CreateOutboxDispatcherTxt, UpdateOutboxDispatcherTxt));
    end;

    procedure GetInboxDispatcherCaption(DispatcherExists: Boolean): Text
    var
        CreateInboxDispatcherTxt: Label 'Create inbox dispatcher';
        UpdateInboxDispatcherTxt: Label 'Update inbox dispatcher';
    begin
        exit(this.GetDispatcherCaption(DispatcherExists, CreateInboxDispatcherTxt, UpdateInboxDispatcherTxt));
    end;

    procedure GetCleanupDispatcherCaption(DispatcherExists: Boolean): Text
    var
        CreateCleanupDispatcherTxt: Label 'Create cleanup dispatcher';
        UpdateCleanupDispatcherTxt: Label 'Update cleanup dispatcher';
    begin
        exit(this.GetDispatcherCaption(DispatcherExists, CreateCleanupDispatcherTxt, UpdateCleanupDispatcherTxt));
    end;

    local procedure GetDispatcherCaption(DispatcherExists: Boolean; CreateDispatcherTxt: Text; UpdateDispatcherTxt: Text): Text
    begin
        if DispatcherExists then
            exit(UpdateDispatcherTxt);

        exit(CreateDispatcherTxt);
    end;

    procedure SetupOutboxDispatcherJob(IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    var
        OutboxDispatcherDescriptionTxt: Label 'Integration Monitor outbox dispatcher';
    begin
        this.EnsureDispatcherJob(Codeunit::"AMC Outbox Dispatcher Job", OutboxDispatcherDescriptionTxt, IntervalInMinutes, JobQueueCategoryCode);
    end;

    procedure SetupInboxDispatcherJob(IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    var
        InboxDispatcherDescriptionTxt: Label 'Integration Monitor inbox dispatcher';
    begin
        this.EnsureDispatcherJob(Codeunit::"AMC Inbox Dispatcher Job", InboxDispatcherDescriptionTxt, IntervalInMinutes, JobQueueCategoryCode);
    end;

    procedure SetupCleanupDispatcherJob(IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    var
        CleanupDescriptionTxt: Label 'Integration Monitor outbox cleanup';
    begin
        this.EnsureDispatcherJob(Codeunit::"AMC Outbox Cleanup Job", CleanupDescriptionTxt, IntervalInMinutes, JobQueueCategoryCode);
    end;

    local procedure EnsureDispatcherJob(CodeunitId: Integer; JobDescription: Text[100]; IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        this.CheckInterval(IntervalInMinutes);

        if this.GetDispatcherJob(CodeunitId, JobQueueEntry) then begin
            this.UpdateDispatcherJob(JobQueueEntry, JobDescription, IntervalInMinutes, JobQueueCategoryCode);
            exit;
        end;

        this.InsertDispatcherJob(CodeunitId, JobDescription, IntervalInMinutes, JobQueueCategoryCode);
    end;

    local procedure CheckInterval(IntervalInMinutes: Integer)
    var
        IntervalMustBePositiveErr: Label 'The interval must be one minute or more.';
    begin
        if IntervalInMinutes < 1 then
            Error(IntervalMustBePositiveErr);
    end;

    local procedure UpdateDispatcherJob(var JobQueueEntry: Record "Job Queue Entry"; JobDescription: Text[100]; IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    begin
        this.AssignDispatcherJobSettings(JobQueueEntry, JobDescription, IntervalInMinutes, JobQueueCategoryCode);
        JobQueueEntry.Modify(true);
        this.SetReady(JobQueueEntry);
    end;

    local procedure InsertDispatcherJob(CodeunitId: Integer; JobDescription: Text[100]; IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.Init();
        JobQueueEntry.Validate("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.Validate("Object ID to Run", CodeunitId);
        this.AssignDispatcherJobSettings(JobQueueEntry, JobDescription, IntervalInMinutes, JobQueueCategoryCode);
        JobQueueEntry.Insert(true);
        this.SetReady(JobQueueEntry);
    end;

    local procedure AssignDispatcherJobSettings(var JobQueueEntry: Record "Job Queue Entry"; JobDescription: Text[100]; IntervalInMinutes: Integer; JobQueueCategoryCode: Code[10])
    begin
        JobQueueEntry.Validate(Description, JobDescription);
        JobQueueEntry.Validate("Job Queue Category Code", JobQueueCategoryCode);
        JobQueueEntry.Validate("Recurring Job", true);
        JobQueueEntry.Validate("No. of Minutes between Runs", IntervalInMinutes);
        JobQueueEntry.Validate("Maximum No. of Attempts to Run", 0);
        JobQueueEntry.Validate("Run on Mondays", true);
        JobQueueEntry.Validate("Run on Tuesdays", true);
        JobQueueEntry.Validate("Run on Wednesdays", true);
        JobQueueEntry.Validate("Run on Thursdays", true);
        JobQueueEntry.Validate("Run on Fridays", true);
        JobQueueEntry.Validate("Run on Saturdays", true);
        JobQueueEntry.Validate("Run on Sundays", true);
    end;

    local procedure SetReady(var JobQueueEntry: Record "Job Queue Entry")
    begin
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;

    procedure ShowOutboxJobQueueEntry()
    begin
        this.ShowJobQueueEntry(Codeunit::"AMC Outbox Dispatcher Job");
    end;

    procedure ShowInboxJobQueueEntry()
    begin
        this.ShowJobQueueEntry(Codeunit::"AMC Inbox Dispatcher Job");
    end;

    procedure ShowCleanupJobQueueEntry()
    begin
        this.ShowJobQueueEntry(Codeunit::"AMC Outbox Cleanup Job");
    end;

    local procedure ShowJobQueueEntry(CodeunitId: Integer)
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        if not this.GetDispatcherJob(CodeunitId, JobQueueEntry) then
            exit;

        Page.RunModal(Page::"Job Queue Entry Card", JobQueueEntry);
    end;

    procedure CompleteAssistedSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"AMC Int. Job Queue Setup");
    end;
}
