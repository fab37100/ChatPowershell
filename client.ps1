# =======================================================
# NAME: client.ps1
# AUTHOR: FabiOus37
# DATE: 02/07/2017
#
# VERSION 1.0
# COMMENTS: Change variable $adresseBaseRedis with your own IP address or hostname of your redis server 
#
#Requires -Version 4.0
# =======================================================

#region Supression de la console powershell, A COMMENTER (DESACTIVER) SI ON VEUT LA CONSOLE POWERSHELL EN ARRIERE PLAN

$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

#endregion

#region importation des modules et assemblies

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
Import-Module .\PowerRedis\PowerRedis.psd1

#endregion

#region Définition des variables

$adresseBaseRedis = "XXXX"
$global:idValid = $false
$global:positionMessage = 0
$global:dateMessage = Get-Date -Format yyyyMMdd

#endregion

#region Définition des timer qui seront executés en arrière plan

$timer = New-Object System.Windows.Forms.Timer   #Création de l'objet Timer
$timer.Interval = 500    #Intervale d'execution des actions régler à 0,5s

$timer2 = New-Object System.Windows.Forms.Timer   #Création de l'objet Timer
$timer2.Interval = 3000    #Intervale d'execution des actions régler à 3s

#endregion

#connexion à la base REDIS du serveur
Connect-RedisServer -RedisServer $adresseBaseRedis

#region Fonctions

#Fonction permettant d'afficher un nouveau message dans la listbox
function AffichageNouveauMessage {
    #Vérification que la table du jour existe bien sinon cela veut dire qu'il n'y a pas de nouveau msg aujourd'hui
    if (Get-RedisExists -key $global:dateMessage){
        # Si la position du dernier message connu par l'interface Chat est inférieur à la position du dernier message dans la table de la base
        # alors le(s) nouveau(x) message(s) est/sont récupéré(s) est affiché(s) dans l'interface Chat
        if ((Get-RedisListLength -key $global:dateMessage) -gt $global:positionMessage){
            $nouveauMessages = Get-RedisListRange -Name $global:dateMessage -StartIndex $global:positionMessage -EndIndex -1
            foreach ($newMSG in $nouveauMessages){
                $global:corpsHisto.AddText($newMSG)
            }
            #récupération de la position du dernier message de la table
            $global:positionMessage = Get-RedisListLength -key $global:dateMessage
            $global:corpsHisto.SelectedIndex = $global:corpsHisto.Items.Count -1
        }
    }
}

#endregion

#region Définition des fenêtres

#Définition de l'affichage de connexion au chat
[xml]$xaml=@"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="PtitChat" Height="166.666" Width="403.431" WindowStartupLocation="CenterScreen">
    <Grid>
        <Button x:Name="btnConnexion" Content="Connexion" HorizontalAlignment="Left" Margin="266,48,0,0" VerticalAlignment="Top" Width="99" Height="44"/>
        <TextBox x:Name="tbIdentifiant" HorizontalAlignment="Left" Height="23" Margin="42,34,0,0" TextWrapping="Wrap" Text="" VerticalAlignment="Top" ToolTip="Entrez votre identifiant de connexion" Width="182"/>
        <PasswordBox x:Name="pbPassword" HorizontalAlignment="Left" Margin="42,86,0,0" VerticalAlignment="Top" Width="182" ToolTip="Entrez votre mot de passe" Height="22"/>
        <Label x:Name="label" Content="Identifiant" HorizontalAlignment="Left" Margin="42,8,0,0" VerticalAlignment="Top" FontStyle="Italic"/>
        <Label x:Name="label1" Content="Mot de passe" HorizontalAlignment="Left" Margin="42,60,0,0" VerticalAlignment="Top" FontStyle="Italic"/>
    </Grid>
</Window>
"@

#Définition de l'affichage du chat
[xml]$xaml2=@"
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PtitChat" Height="458.703" Width="752.899" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid MinWidth="517" MinHeight="319">
        <Button x:Name="Envoyer" Content="Envoyer" Margin="0,365.663,30.406,27.04" RenderTransformOrigin="0.147,1.102" HorizontalAlignment="Right" Width="100"/>
        <TextBox x:Name="Message" Margin="40,365.663,166,27.04" TextWrapping="Wrap">
            <TextBox.Style>
                <Style TargetType="TextBox" xmlns:sys="clr-namespace:System;assembly=mscorlib">
                    <Style.Resources>
                        <VisualBrush x:Key="CueBannerBrush" AlignmentX="Left" AlignmentY="Center" Stretch="None">
                            <VisualBrush.Visual>
                                <Label Content="Entrer votre message" Foreground="Gray" />
                            </VisualBrush.Visual>
                        </VisualBrush>
                    </Style.Resources>
                    <Style.Triggers>
                        <Trigger Property="Text" Value="{x:Static sys:String.Empty}">
                            <Setter Property="Background" Value="{StaticResource CueBannerBrush}" />
                        </Trigger>
                        <Trigger Property="Text" Value="{x:Null}">
                            <Setter Property="Background" Value="{StaticResource CueBannerBrush}" />
                        </Trigger>
                        <Trigger Property="IsKeyboardFocused" Value="True">
                            <Setter Property="Background" Value="White" />
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </TextBox.Style>
        </TextBox>
        <ListBox x:Name="CorpsHistorique" Margin="40,26.5,166,78.203"/>
        <Label x:Name="Label1" Content="Utilisateurs connectés" FontStyle="Italic" Margin="589.84,28,24.405,359.783"/>
        <ListBox x:Name="CorpsUsersOnline" Margin="0,0,30.406,121.703" RenderTransformOrigin="0.2,1.125" HorizontalAlignment="Right" Width="100" Height="235" VerticalAlignment="Bottom" Background="#FFF0ECEC" IsEnabled="False"/>
    </Grid>
</Window>
"@
#endregion

#Chargement de l'interface de connexion
$wpf=(New-Object System.Xml.XmlNodeReader $xaml)
$Form=[Windows.Markup.XamlReader]::Load($wpf)

#Récupération des objets de l'interface
$btnConnexion = $Form.FindName('btnConnexion')
$conRedisPassword = $Form.FindName('pbPassword')
$conRedisIdentifiant = $Form.FindName('tbIdentifiant')

#Action lorsque le bouton connexion est éxécuté
$btnConnexion.Add_Click({
    try {
        #Vérification que l'utilisateur existe et que le mot de passe soit correct
        if ((Get-RedisHashExists -Hash users -Key $conRedisIdentifiant.text) -And ((Get-RedisHashValue -Hash users -key $conRedisIdentifiant.text) -eq $conRedisPassword.Password)) {
            #Vérification que l'utilisateur n'est pas déjà connécté
            if ((Get-RedisHashValue -Hash usersOnline -Key $conRedisIdentifiant.text) -eq 0){
                [System.Windows.Forms.MessageBox]::Show("Vous êtes maintenant connecté en tant que : $($conRedisIdentifiant.text)","Erreur authentification",0,64)
                #Modification de la varibale idValid à vrai afin de continuer vers l'interface du chat
                $global:idValid = $True
                #Modification à 1 (connecté) du statut de l'utilisateur sur la base
                Set-RedisHashValue -Hash usersOnline -Key $conRedisIdentifiant.text -Value 1
                $Form.Close()
            } Else {
                #Affichage du message d'erreur si l'utilisateur est déjà connecté
                [System.Windows.Forms.MessageBox]::Show("L'utilisateur est déjà connecté","Erreur connexion",0,16)
            }
        } else {
            #Affichage d'un message d'erreur si le mdp ou l'id n'est pas bon
            [System.Windows.Forms.MessageBox]::Show("Le mot de passe ou l'identifiant n'est pas correct","Erreur authentification",0,16)
       }
   }catch{
        #Affichage d'un message d'erreur si la connexion à la base est KO
        [System.Windows.Forms.MessageBox]::Show("Impossible de se connecter à la base de donnée $adresseBaseRedis !","Erreur connexion",0,16)
   }
})

#Affichage de l'interface de connexion
$Form.ShowDialog() | out-null

#Demarrage de l'interface chat si la connexion à la base est authentifiée
if ($global:idValid){
    #Chargement de l'nterface Chat
    $wpf=(New-Object System.Xml.XmlNodeReader $xaml2)
    $Form=[Windows.Markup.XamlReader]::Load($wpf)
    $Form.Title = "{0} : {1}" -f $Form.Title, $conRedisIdentifiant.text 

    #Récupération des contrôles WPF dans PowerShell
    $global:corpsHisto = $Form.FindName('CorpsHistorique')
    $btnEnvoyer = $Form.FindName('Envoyer')
    $listMessage = $Form.FindName('Message')
    $corpsUsersOnline = $Form.FindName('CorpsUsersOnline')

    #Action du timer
    $timer.add_tick({
        #Affichage des nouveaux messages s'il y en a
        AffichageNouveauMessage
    })

    #Action du deuxième timer
    $timer2.add_tick({
        $nbUsers = Get-RedisHashAll -Hash usersOnline
        foreach ($user in $nbUsers.keys){
            #Récupoération des utilisateurs en ligne
            if ((Get-RedisHashValue -Hash usersOnline -Key $user) -eq 1) {
                #Si l'utilisateur n'est pas dans "Utilisateurs connectés" du Chat alors il est ajouté
                if (!($corpsUsersOnline.Items -eq $user)){
                    $corpsUsersOnline.AddText($user)
                }
            #Récupération des utilisateurs hors ligne
            }else{
                #Si l'utilisateur est dans "Utilisateurs connectés" du chat alors il est retiré
                if (!(($corpsUsersOnline.items.IndexOf($user)) -eq -1)){
                    $corpsUsersOnline.items.Remove($corpsUsersOnline.items[($corpsUsersOnline.items.IndexOf($user))])
                }
            }
        }
    })

    #Action lorsque le buton envoyer est selectionné
    $btnEnvoyer.Add_Click({
        #Vérification qu'il y a bien au moins 1 caratère dans l'emplacement listMessage
        if (!($listMessage.Text.length -eq 0)){
            $global:dateMessage = Get-Date -Format yyyyMMdd
            #Formatage du message commençant par la date actuelle puis de l'utilisateur et de son message
            $monMessage = "[{0}]{1}: {2}" -f (Get-Date), $conRedisIdentifiant.text, $listMessage.Text
            $global:positionMessage = Get-RedisListLength -key $global:dateMessage
            #Ajout du message dans la table du jour (si elle n'existe pas elle est créée)
            Add-RedisListItem -name $dateMessage -ListItem $monMessage
            AffichageNouveauMessage
            #Réinitialisation du message
            $monMessage, $listMessage.Text = $null
        }
    })

    #action lorsque l'interface est quittée
    $Form.add_closing({
        #Arrêt des timers
        $timer.stop()
        $timer2.stop()
        #Modification de l'état de l'utisation sur la base en 0 (hors ligne)
        Set-RedisHashValue -Hash usersOnline -Key $conRedisIdentifiant.text -Value 0
    })

    #Démarrage des timers
    $timer.Start()
    $timer2.Start()

    $Form.ShowDialog() | out-null
}
