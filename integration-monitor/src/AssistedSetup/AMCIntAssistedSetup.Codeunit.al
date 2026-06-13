namespace Addmecode.IntegrationMonitor.AssistedSetup;

using System.Environment.Configuration;
using System.Media;

codeunit 50137 "AMC Int. Assisted Setup"
{
  [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", 'OnRegisterAssistedSetup', '', false, false)]
  local procedure OnRegisterAssistedSetup()
  var
    GuidedExperience: Codeunit "Guided Experience";
    JobQueueSetupDescriptionTxt: Label 'Create recurring job queue entries for processing Integration Monitor outbox entries, inbox entries, and cleanup.';
    JobQueueSetupShortTitleTxt: Label 'Integration Monitor jobs';
    JobQueueSetupTitleTxt: Label 'Set up Integration Monitor job queues';
  begin
    GuidedExperience.InsertAssistedSetup(JobQueueSetupTitleTxt, JobQueueSetupShortTitleTxt, JobQueueSetupDescriptionTxt, 2, ObjectType::Page, Page::"AMC Int. Job Queue Setup", "Assisted Setup Group"::Extensions, '', "Video Category"::Uncategorized, '');
  end;
}
