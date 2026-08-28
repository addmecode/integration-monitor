namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using System.TestLibraries.Utilities;

codeunit 50144 "AMC Basic Auth Handler Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";
        AuthorizationHeaderLbl: Label 'Authorization', Locked = true;

    [Test]
    procedure WhenApplyAuth_ThenSetsSecretAuthorizationHeader()
    var
        Profile: Record "AMC Int. Auth Profile";
        BasicAuthHandler: Codeunit "AMC Int. Basic Auth Handler";
        Request: HttpRequestMessage;
        RequestHeaders: HttpHeaders;
    begin
        // [SCENARIO] The Basic handler puts an Authorization header on the request, stored as a secret.
        // [GIVEN] A Basic profile with a Username and a stored password.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);

        // [WHEN] ApplyAuth runs against a fresh request.
        BasicAuthHandler.ApplyAuth(Request, Profile);

        // [THEN] The request carries a secret Authorization header (its base64 value is not readable).
        Request.GetHeaders(RequestHeaders);
        this.Assert.IsTrue(RequestHeaders.ContainsSecret(this.AuthorizationHeaderLbl), 'ApplyAuth should add a secret Authorization header.');
    end;

    [Test]
    procedure WhenApplyAuthWithExistingHeader_ThenReplacesIt()
    var
        Profile: Record "AMC Int. Auth Profile";
        BasicAuthHandler: Codeunit "AMC Int. Basic Auth Handler";
        Request: HttpRequestMessage;
        RequestHeaders: HttpHeaders;
    begin
        // [SCENARIO] An existing Authorization header is replaced, not duplicated.
        // [GIVEN] A request that already carries a plain Authorization header and a Basic profile with a secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add(this.AuthorizationHeaderLbl, 'Basic stale-value');

        // [WHEN] ApplyAuth runs against that request.
        BasicAuthHandler.ApplyAuth(Request, Profile);

        // [THEN] The plain header is gone and a single secret Authorization header remains.
        Request.GetHeaders(RequestHeaders);
        this.Assert.IsTrue(RequestHeaders.ContainsSecret(this.AuthorizationHeaderLbl), 'A secret Authorization header should be present after replacement.');
    end;

    [Test]
    procedure WhenValidateProfileWithoutUsername_ThenErrors()
    var
        Profile: Record "AMC Int. Auth Profile";
        BasicAuthHandler: Codeunit "AMC Int. Basic Auth Handler";
    begin
        // [SCENARIO] The Basic handler's ValidateProfile requires the Username.
        // [GIVEN] A Basic profile with a blank Username.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);
        Profile.Username := '';
        Profile.Modify(true);

        // [WHEN] ValidateProfile runs against it.
        asserterror BasicAuthHandler.ValidateProfile(Profile);

        // [THEN] It errors via TestField(Username).
        this.Assert.ExpectedError(Profile.FieldCaption(Username));
    end;
}
