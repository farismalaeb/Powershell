#----------------------------------------------
# Generated Form Function
#----------------------------------------------
function Show-MainForm_psf {

	#----------------------------------------------
	#region Import the Assemblies
	#----------------------------------------------
	[void][reflection.assembly]::Load('System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Data, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	#endregion Import Assemblies

	#----------------------------------------------
	#region Generated Form Objects
	#----------------------------------------------
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$formVDIDataMigrationFari = New-Object 'System.Windows.Forms.Form'
	$groupbox2 = New-Object 'System.Windows.Forms.GroupBox'
	$btnAdd = New-Object 'System.Windows.Forms.Button'
	$listbox1 = New-Object 'System.Windows.Forms.ListBox'
	$groupbox1 = New-Object 'System.Windows.Forms.GroupBox'
	$checkboxInternetExplorerFav = New-Object 'System.Windows.Forms.CheckBox'
	$checkboxPictures = New-Object 'System.Windows.Forms.CheckBox'
	$checkboxMusic = New-Object 'System.Windows.Forms.CheckBox'
	$checkboxDocuments = New-Object 'System.Windows.Forms.CheckBox'
	$chkDesktop = New-Object 'System.Windows.Forms.CheckBox'
	$labelUserName = New-Object 'System.Windows.Forms.Label'
	$textbox1 = New-Object 'System.Windows.Forms.TextBox'
	$InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'
	#endregion Generated Form Objects

	#----------------------------------------------
	#region Generated Form Code
	#----------------------------------------------
	$formVDIDataMigrationFari.SuspendLayout()
	$groupbox1.SuspendLayout()
	$groupbox2.SuspendLayout()
	#
	# formVDIDataMigrationFari
	#
	$formVDIDataMigrationFari.Controls.Add($groupbox2)
	$formVDIDataMigrationFari.Controls.Add($groupbox1)
	$formVDIDataMigrationFari.Controls.Add($labelUserName)
	$formVDIDataMigrationFari.Controls.Add($textbox1)
	$formVDIDataMigrationFari.AutoScaleDimensions = '6, 13'
	$formVDIDataMigrationFari.AutoScaleMode = 'Font'
	$formVDIDataMigrationFari.ClientSize = '308, 381'
	$formVDIDataMigrationFari.MaximizeBox = $False
	$formVDIDataMigrationFari.Name = 'formVDIDataMigrationFari'
	$formVDIDataMigrationFari.Text = 'VDI Data Migration - Faris Malaeb'
	$formVDIDataMigrationFari.add_Load($formVDIDataMigrationFari_Load)
	#
	# groupbox2
	#
	$groupbox2.Controls.Add($btnAdd)
	$groupbox2.Controls.Add($listbox1)
	$groupbox2.Location = '21, 143'
	$groupbox2.Name = 'groupbox2'
	$groupbox2.Size = '251, 146'
	$groupbox2.TabIndex = 3
	$groupbox2.TabStop = $False
	$groupbox2.Text = 'File To Copy'
	#
	# btnAdd
	#
	$btnAdd.Location = '7, 121'
	$btnAdd.Name = 'btnAdd'
	$btnAdd.Size = '75, 23'
	$btnAdd.TabIndex = 1
	$btnAdd.Text = 'Add'
	$btnAdd.UseVisualStyleBackColor = $True
	#
	# listbox1
	#
	$listbox1.FormattingEnabled = $True
	$listbox1.Location = '7, 20'
	$listbox1.Name = 'listbox1'
	$listbox1.Size = '238, 95'
	$listbox1.TabIndex = 0
	#
	# groupbox1
	#
	$groupbox1.Controls.Add($checkboxInternetExplorerFav)
	$groupbox1.Controls.Add($checkboxPictures)
	$groupbox1.Controls.Add($checkboxMusic)
	$groupbox1.Controls.Add($checkboxDocuments)
	$groupbox1.Controls.Add($chkDesktop)
	$groupbox1.Location = '21, 50'
	$groupbox1.Name = 'groupbox1'
	$groupbox1.Size = '251, 87'
	$groupbox1.TabIndex = 2
	$groupbox1.TabStop = $False
	$groupbox1.Text = 'Folders To Copy'
	#
	# checkboxInternetExplorerFav
	#
	$checkboxInternetExplorerFav.Location = '112, 20'
	$checkboxInternetExplorerFav.Name = 'checkboxInternetExplorerFav'
	$checkboxInternetExplorerFav.Size = '133, 24'
	$checkboxInternetExplorerFav.TabIndex = 4
	$checkboxInternetExplorerFav.Text = 'Internet Explorer Fav'
	$checkboxInternetExplorerFav.UseVisualStyleBackColor = $True
	#
	# checkboxPictures
	#
	$checkboxPictures.Location = '112, 39'
	$checkboxPictures.Name = 'checkboxPictures'
	$checkboxPictures.Size = '104, 24'
	$checkboxPictures.TabIndex = 3
	$checkboxPictures.Text = 'Pictures'
	$checkboxPictures.UseVisualStyleBackColor = $True
	$checkboxPictures.add_CheckedChanged($checkboxPictures_CheckedChanged)
	#
	# checkboxMusic
	#
	$checkboxMusic.Location = '20, 58'
	$checkboxMusic.Name = 'checkboxMusic'
	$checkboxMusic.Size = '104, 24'
	$checkboxMusic.TabIndex = 2
	$checkboxMusic.Text = 'Music'
	$checkboxMusic.UseVisualStyleBackColor = $True
	#
	# checkboxDocuments
	#
	$checkboxDocuments.Checked = $True
	$checkboxDocuments.CheckState = 'Checked'
	$checkboxDocuments.Location = '20, 39'
	$checkboxDocuments.Name = 'checkboxDocuments'
	$checkboxDocuments.Size = '104, 24'
	$checkboxDocuments.TabIndex = 1
	$checkboxDocuments.Text = 'Documents'
	$checkboxDocuments.UseVisualStyleBackColor = $True
	#
	# chkDesktop
	#
	$chkDesktop.Checked = $True
	$chkDesktop.CheckState = 'Checked'
	$chkDesktop.Location = '20, 20'
	$chkDesktop.Name = 'chkDesktop'
	$chkDesktop.Size = '116, 24'
	$chkDesktop.TabIndex = 0
	$chkDesktop.Text = 'Desktop'
	$chkDesktop.UseVisualStyleBackColor = $True
	#
	# labelUserName
	#
	$labelUserName.AutoSize = $True
	$labelUserName.Location = '12, 15'
	$labelUserName.Name = 'labelUserName'
	$labelUserName.Size = '57, 13'
	$labelUserName.TabIndex = 1
	$labelUserName.Text = 'UserName'
	#
	# textbox1
	#
	$textbox1.Location = '75, 12'
	$textbox1.Name = 'textbox1'
	$textbox1.Size = '132, 20'
	$textbox1.TabIndex = 0
	$groupbox2.ResumeLayout()
	$groupbox1.ResumeLayout()
	$formVDIDataMigrationFari.ResumeLayout()
	#endregion Generated Form Code

	#----------------------------------------------

	#Save the initial state of the form
	$InitialFormWindowState = $formVDIDataMigrationFari.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$formVDIDataMigrationFari.add_Load($Form_StateCorrection_Load)
	#Clean up the control events
	$formVDIDataMigrationFari.add_FormClosed($Form_Cleanup_FormClosed)
	#Show the Form
	return $formVDIDataMigrationFari.ShowDialog()

} #End Function

#Call the form
Show-MainForm_psf | Out-Null
