## Start a Chat Session using the New-MgChat to create a session ID
$params = @{
	ChatType = "oneOnOne"
	Members = @(
		@{
			"@odata.type" = "#microsoft.graph.aadUserConversationMember"
			Roles = @(
				"owner"
			)
			"User@odata.bind" = "https://graph.microsoft.com/v1.0/users('8ef78f89-6e65-433d-8287-4c68a5facb19')"
		}
		@{
			"@odata.type" = "#microsoft.graph.aadUserConversationMember"
			Roles = @(
				"owner"
			)
			"User@odata.bind" = "https://graph.microsoft.com/v1.0/users('5e65eafa-b72e-4e69-b164-19f3febd16f6')"
		}
	)
}

$myChatSession=New-MgChat -BodyParameter $params

##### Sending Teams Message using New-MgChatMessage

$Body = @{
  ContentType = 'html'
  Content = @'
   Hello Mr/Mis <at id="0">Mr. VDI One</at> and <at id="1">Mis. VDI Two</at>
  <img height="200" src="../hostedContents/1/$value" width="200" style="vertical-align:bottom; width:700px; height:700px">
  <Strong>Thanks for your attention</Strong>
  <img height="200" src="../hostedContents/2/$value" width="200" style="vertical-align:bottom; width:700px; height:700px">
'@
}
$HostedContents = @(
  @{
      "@microsoft.graph.temporaryId" = "1"
      ContentBytes = [System.IO.File]::ReadAllBytes("C:\Users\f.malaeb\Pictures\ShellBot.png")
      ContentType = "image/png"
  }
  @{
    "@microsoft.graph.temporaryId" = "2"
    ContentBytes = [System.IO.File]::ReadAllBytes("C:\Users\f.malaeb\Pictures\Thanks.jpg")
    ContentType = "image/png"
}
)

$Mentions = @(
		@{
			Id = 0
			MentionText = "Mr. VDI One"
			Mentioned = @{
				User = @{
					Id = "5e65eafa-b72e-4e69-b164-19f3febd16f6"
					UserIdentityType = "aadUser"
				}
			}
		}
        @{
			Id = 1
			MentionText = "Mis. VDI Two"
			Mentioned = @{
				User = @{
					Id = "60c7653a-4215-474d-b535-8bb413458047"
					UserIdentityType = "aadUser"
				}
			}
		}
	)

New-MgChatMessage -ChatId $myChatSession.id -Body $Body -HostedContents $HostedContents -Mentions $Mentions 




