namespace Addmecode.IntegrationMonitor.Test;
using System.TestLibraries.Utilities;

codeunit 50141 "AMC Smoke Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure WhenTestRunnerExecutes_ThenScaffoldPassesGreen()
    var
        Assert: Codeunit "Library Assert";
    begin
        // [SCENARIO] The test app compiles and the test runner executes a test.
        // [GIVEN] A trivial assertion.
        // [THEN] It passes, validating the whole Phase 0 scaffold.
        Assert.IsTrue(true, 'Smoke test should always pass.');
    end;
}
