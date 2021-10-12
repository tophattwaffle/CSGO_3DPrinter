using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection.Metadata.Ecma335;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;
using PrimS.Telnet;
using Renci.SshNet;

namespace CSGO_3DPrinter
{
    class Program
    {
        private static Client _client;
        private static SshClient _sshClient;
        private static ShellStream _shellStreamSSH;
        private static string sshTarget = "172.16.22.195";
        private static int sshPort = 2222;
        private static string sshUser = "csgo";
        private static string sshPassword = "P4ssw0rd!"; //this isn't a prod password
        private static readonly List<string> csgoTaskList = new List<string>();
        private static readonly List<string> octoprintTaskList = new List<string>();
        private static bool _forwardToCsgo = false;
        private static bool _forwardToOctoprint = false;
        private static string _currentOctoprintState;

        //If anyone complains about how bad this is, just think about the goal of what this code does.
        //There is no point, it's stupid as heck.
        static async Task Main(string[] args)
        {
            var connectionInfo = new ConnectionInfo(sshTarget,sshPort,sshUser,
                new PasswordAuthenticationMethod(sshUser, sshPassword));

            Console.WriteLine("Connecting to SSH");
            _sshClient = new SshClient(connectionInfo);
            
            _sshClient.Connect();
            Console.WriteLine($"SSH Connected: {_sshClient.IsConnected}");

            _shellStreamSSH = _sshClient.CreateShellStream("", 0, 0, 0, 0, 512);
            _ = Task.Run(async () => ReadSSHStream());

            while (_client == null || !_client.IsConnected)
            {
                Console.WriteLine("Waiting for game client...");
                try
                {
                    _client = new Client("localhost", 2121, new CancellationToken());
                }
                catch
                {
                    Console.WriteLine("Unable to connect, trying again...");
                }
                
            }
            Console.WriteLine("Connected to CSGO!");

            //Start listening forever and always
            _ = Task.Run(async () => ListenCSGO());

            await Task.Delay(2000);
            SendToOctoprint("terminal");
            _forwardToCsgo = true;

            while (true)
            {
                //octoprintTaskList contains commands to be sent TO octoprint
                if (octoprintTaskList.Count != 0)
                {

                }

                //csgoTaskList contains commands to be sent TO csgo
                if (csgoTaskList.Count != 0)
                {
                    await SendMessageToCsgo(csgoTaskList[0]);
                    csgoTaskList.RemoveAt(0);
                }

                await Task.Delay(20);
            }
        }

        //All CSGO stuff is handled inside the vscript
        public static async Task SendMessageToCsgo(string message)
        {
            if (message == null)
                return;
            message = message.Replace('"', '\'');
            Console.WriteLine($"To CSGO: {message}");
            await _client.WriteLine($"script IncomingMessage(\"{message}\")");
        }

        /// <summary>
        /// Commands that come from CSGO will land here
        /// </summary>
        /// <param name="command"></param>
        /// <returns></returns>
        public static async Task HandleCommandFromCSGO(string command)
        {
            switch (command)
            {
                case "terminal":

                    _ = Task.Run(async () =>{
                        await Task.Delay(2000);
                        _forwardToCsgo = true;
                    });

                    if (_currentOctoprintState == "root")
                        SendToOctoprint("terminal");
                    //todo handle non-root entry
                    break;
                default:
                    await SendMessageToCsgo($"script printl(\"Unknown command: {command}\")");
                    break;
            }
        }

        public static void SendToOctoprint(string message)
        {
            _shellStreamSSH.WriteLine(message);
        }

        public static async Task ReadSSHStream()
        {
            Console.WriteLine("Starting SSH Stream");
            _currentOctoprintState = "root";
            while (true)
            {
                if (_shellStreamSSH.CanRead)
                {
                    byte[] buffer = new byte[512];
                    int i = await _shellStreamSSH.ReadAsync(buffer, 0, buffer.Length);

                    if (i != 0)
                    {
                        string reply = _sshClient.ConnectionInfo.Encoding.GetString(buffer, 0, i).Trim();
                        reply = Regex.Replace(reply, @"\p{C}+", string.Empty)
                            .Replace("[2K",String.Empty)
                            .Replace("[1A",String.Empty)
                            .Replace(">", string.Empty);
                        if (string.IsNullOrWhiteSpace(reply) || reply.Length < 2)
                            continue;

                        var arrayReply = reply.Split("Recv: ");

                        foreach (var s in arrayReply)
                        {
                            var trimmedS = s.Replace("ok", string.Empty)
                                .Replace(">", string.Empty)
                                .Replace("wait", string.Empty)
                                .Trim();
                            if (string.IsNullOrWhiteSpace(trimmedS))
                                continue;

                            Console.WriteLine($"From Octoprint: {trimmedS}");
                            if(_forwardToCsgo)
                                csgoTaskList.Add(trimmedS);
                        }
                    }
                }
            }
        }

        public static async Task ListenCSGO()
        {
            Console.WriteLine("Listening to CSGO!");
            while (true)
            {
                var reply = await _client.ReadAsync(TimeSpan.FromSeconds(1));
                if (string.IsNullOrEmpty(reply))
                    continue;
                Console.WriteLine($"From CSGO: {reply}");
                if(_forwardToOctoprint)
                    octoprintTaskList.Add(reply);
            }
        }
    }
}
