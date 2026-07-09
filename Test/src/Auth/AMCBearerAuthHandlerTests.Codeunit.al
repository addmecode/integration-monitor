namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using System.TestLibraries.Utilities;

codeunit 50145 "AMC Bearer Auth Handler Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // NOTE: ApplyAuth adds the Authorization header via the SecretText overload of HttpHeaders.Add,
    // so the header is a *secret* header whose "Bearer <token>" value cannot be read back (GetValues
    // returns false for it). The tests assert the header is present as a secret header and that an
    // existing plain Authorization header is replaced, rather than asserting the exact token value.

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";
        AuthorizationHeaderLbl: Label 'Authorization', Locked = true;

    [Test]
    procedure WhenApplyAuth_ThenSetsSecretAuthorizationHeader()
    var
        Profile: Record "AMC Int. Auth Profile";
        BearerAuthHandler: Codeunit "AMC Int. Bearer Auth Handler";
        Request: HttpRequestMessage;
        RequestHeaders: HttpHeaders;
    begin
        // [SCENARIO] The Bearer handler puts an Authorization header on the request, stored as a secret.
        // [GIVEN] A Bearer profile with a stored token.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::"Bearer Token", true);

        // [WHEN] ApplyAuth runs against a fresh request.
        BearerAuthHandler.ApplyAuth(Request, Profile);

        // [THEN] The request carries a secret Authorization header (its token value is not readable).
        Request.GetHeaders(RequestHeaders);
        this.Assert.IsTrue(RequestHeaders.ContainsSecret(this.AuthorizationHeaderLbl), 'ApplyAuth should add a secret Authorization header.');
    end;

    [Test]
    procedure WhenApplyAuthWithExistingHeader_ThenReplacesIt()
    var
        Profile: Record "AMC Int. Auth Profile";
        BearerAuthHandler: Codeunit "AMC Int. Bearer Auth Handler";
        Request: HttpRequestMessage;
        RequestHeaders: HttpHeaders;
    begin
        // [SCENARIO] An existing Authorization header is replaced, not duplicated.
        // [GIVEN] A request that already carries a plain Authorization header and a Bearer profile with a token.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::"Bearer Token", true);
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add(this.AuthorizationHeaderLbl, 'Bearer stale-token');

        // [WHEN] ApplyAuth runs against that request.
        BearerAuthHandler.ApplyAuth(Request, Profile);

        // [THEN] The plain header is gone and a single secret Authorization header remains.
        Request.GetHeaders(RequestHeaders);
        this.Assert.IsFalse(RequestHeaders.Contains(this.AuthorizationHeaderLbl), 'The pre-existing plain Authorization header should be removed.');
        this.Assert.IsTrue(RequestHeaders.ContainsSecret(this.AuthorizationHeaderLbl), 'A secret Authorization header should be present after replacement.');
    end;
}
