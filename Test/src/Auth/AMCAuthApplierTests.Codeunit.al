namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using System.TestLibraries.Utilities;

codeunit 50146 "AMC Auth Applier Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        AuthorizationHeaderLbl: Label 'Authorization', Locked = true;

    [Test]
    procedure WhenApplyAuthWithEmptyCode_ThenNoOp()
    var
        AuthApplier: Codeunit "AMC Int. Auth Applier";
        Request: HttpRequestMessage;
        RequestHeaders: HttpHeaders;
    begin
        // [SCENARIO] An empty auth profile code is a no-op: no header is added and no error is raised.
        // [GIVEN] A fresh request and an empty auth profile code.

        // [WHEN] ApplyAuth runs with an empty code.
        AuthApplier.ApplyAuth(Request, '');

        // [THEN] The request carries no Authorization header (neither plain nor secret).
        Request.GetHeaders(RequestHeaders);
        this.Assert.IsFalse(RequestHeaders.ContainsSecret(this.AuthorizationHeaderLbl), 'An empty auth code should not add a secret Authorization header.');
    end;

    [Test]
    procedure WhenApplyAuthWithMissingProfile_ThenErrors()
    var
        AuthProfile: Record "AMC Int. Auth Profile";
        AuthApplier: Codeunit "AMC Int. Auth Applier";
        Request: HttpRequestMessage;
        MissingCode: Code[20];
        MissingProfileErr: Label 'does not exist', Locked = true;
    begin
        // [SCENARIO] Referencing a non-existent auth profile errors.
        // [GIVEN] An auth profile code that does not exist.
        MissingCode := 'NOSUCHPROFILE';
        if AuthProfile.Get(MissingCode) then
            AuthProfile.Delete(true);

        // [WHEN] ApplyAuth runs with that code.
        asserterror AuthApplier.ApplyAuth(Request, MissingCode);

        // [THEN] It errors that the authentication profile does not exist.
        this.Assert.ExpectedError(MissingProfileErr);
    end;
}
