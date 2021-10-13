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
        private static List<string> csgoTaskList = new List<string>();
        private static List<string> octoPrintFileList = new List<string>();
        private static bool _forwardToCsgo = false;
        

        //Octoprint must have: https://github.com/kantlivelong/OctoPrint-SSHInterface
        //CSGO requires -netconport 2121

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

            //Spam breaks to make sure we are at the top level in the SSH terminal.
            await Task.Delay(2000);
            await SSHBreak();

            while (true)
            {
                //csgoTaskList contains commands to be sent TO csgo
                if (csgoTaskList.Count != 0)
                {
                    await SendMessageToCsgo(csgoTaskList[0]);
                    csgoTaskList.RemoveAt(0);
                }

                await Task.Delay(5);
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

        public static async Task SSHBreak()
        {
            await Task.Delay(250);
            _shellStreamSSH.WriteLine("\u0003");
            await Task.Delay(250);
            _shellStreamSSH.WriteLine("\u0003");
        }

        /// <summary>
        /// Commands that come from CSGO will land here
        /// </summary>
        /// <param name="command"></param>
        /// <returns></returns>
        public static async Task HandleCommandFromCSGO(string command)
        {
            string filename = "";
            if (command.StartsWith("start"))
            {
                var index = command.Split('_');
                var fileIndex = int.Parse(index[1]);
                filename = octoPrintFileList[fileIndex];
                command = "start";
            }
            switch (command)
            {
                case "terminal":
                    await SSHBreak();
                    _shellStreamSSH.WriteLine("terminal");

                    _ = Task.Run(async () => {
                        //await Task.Delay(2000);
                        _forwardToCsgo = true;
                    });

                    break;
                case "updateFiles":
                    _forwardToCsgo = false;
                    await SSHBreak();
                    await Task.Delay(500);
                    await GetFilesFromSSH();
                    break;
                case "start":
                    _forwardToCsgo = false;
                    await SSHBreak();
                    _shellStreamSSH.WriteLine($"print \"/uploads/{filename}.gcode\"");
                    await HandleCommandFromCSGO("terminal");
                    break;
                default:
                    await SendMessageToCsgo($"script printl(\"Unknown command: {command}\")");
                    break;
            }
        }

        public static async Task GetFilesFromSSH()
        {
            Console.WriteLine("Getting SSH file list");
            octoPrintFileList = new List<string>();
            _shellStreamSSH.WriteLine("ls uploads");
            await Task.Delay(1000);
            Console.WriteLine("Done collecting files...");
            
            //The first file always sucks because I suck.
            octoPrintFileList.RemoveAt(0);
            foreach (var o in octoPrintFileList)
            {
                await _client.WriteLine($"script HandleIncomingFiles(\"{o}\")");
            }
        }

        public static async Task ReadSSHStream()
        {
            Console.WriteLine("Starting SSH Stream");
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

                        if (reply.Contains(".gcode"))
                        {
                            reply = reply.Replace("ls uploads", string.Empty).Replace(@"[/]$",string.Empty).Replace(".metadata.json",string.Empty).Replace("loads",string.Empty);
                            Console.WriteLine(reply);
                            foreach (var s in reply.Split(".gcode"))
                            {
                                if (string.IsNullOrWhiteSpace(s))
                                    continue;
                                octoPrintFileList.Add(s);
                            }
                        }

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
                var reply = await _client.ReadAsync();
                if (string.IsNullOrEmpty(reply))
                    continue;
                if(reply.StartsWith("[OCTO]"))
                    await HandleCommandFromCSGO(reply.Replace("[OCTO]",string.Empty).Trim());
            }
        }
    }
}
