using System;
using System.Collections.Generic;
using System.ComponentModel.Design;
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
        private static List<DateTime> messageRateList = new List<DateTime>();
        private static List<string> consoleOutput = new List<string>();

        //Octoprint must have: https://github.com/kantlivelong/OctoPrint-SSHInterface
        //CSGO requires -netconport 2121

        //If anyone complains about how bad this is, just think about the goal of what this code does.
        //There is no point, it's stupid as heck.
        static async Task Main(string[] args)
        {
            var connectionInfo = new ConnectionInfo(sshTarget,sshPort,sshUser,
                new PasswordAuthenticationMethod(sshUser, sshPassword));
            Console.Title = $"CSGOctoPrint";
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

            _ = Task.Run(async () => UpdateTitle());

            while (true)
            {
                
                //csgoTaskList contains commands to be sent TO csgo
                if (csgoTaskList.Count != 0)
                {
                    await SendMessageToCsgo(csgoTaskList[0]);
                    messageRateList.Add(DateTime.Now);

                    csgoTaskList.RemoveAt(0);

                    //This helps keep the command queue full so we don't hit race conditions
                    //Also ensures we have AT LEAST 5 seconds of commands in the draw "buffer"
                    //to have a smoother drawing experience inside CSGO.
                    if (csgoTaskList.Count < 50)
                        await Task.Delay(100);
                }
            }
        }

        public static async Task UpdateTitle()
        {
            consoleOutput.Add("Starting title updates!");
            while (true)
            {
                
                messageRateList.RemoveAll(x => x <= DateTime.Now.AddSeconds(-1));
                Console.Title =
                    $"CSGOctoPrint - Message Queue: [{csgoTaskList.Count}] - Message Rate: [{messageRateList.Count}]/s";
                try
                    {
                    if (consoleOutput.Count > Console.WindowHeight)
                        consoleOutput.RemoveRange(0, consoleOutput.Count - Console.WindowHeight);
                    string output = "";
                    for (int i = 0; i < consoleOutput.Count - 1; i++)
                    {
                        string newCommand = consoleOutput[i];
                        string whiteSpace = "";

                        //Use this to overwrite any space that would have been otherwise caused from variable string lengths
                        for (int j = 0; j < Console.WindowWidth - newCommand.Length - 1; j++)
                        {
                            whiteSpace += " ";
                        }

                        output += newCommand + whiteSpace + "\n";
                    }

                    //By moving the cursor up top, we can prevent wild flickering the we'd get with Console.Clear()
                    Console.SetCursorPosition(0, 0);
                    Console.Write(output);
                    await Task.Delay(250);
                }
                catch (Exception e)
                {
                    Console.WriteLine(e);
                }
            }
        }

        //All CSGO stuff is handled inside the vscript
        public static async Task SendMessageToCsgo(string message)
        {
            if (message == null)
                return;
            message = message.Replace('"', '\'');
            consoleOutput.Add($"To CSGO:[{message}]");
            //Console.WriteLine($"To CSGO:[{message}]");
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
            if (command.Contains("\r\n"))
            {
                var split = command.Split("\r\n");
                command = split[0];
            }
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

                    _forwardToCsgo = true;

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
                    _shellStreamSSH.WriteLine($"print \"/uploads/{filename}\"");
                    await HandleCommandFromCSGO("terminal");
                    break;
                default:
                    await SendMessageToCsgo($"script printl(\"Unknown command: {command}\")");
                    break;
            }
        }

        public static async Task GetFilesFromSSH()
        {
            //Console.WriteLine("Getting SSH file list");
            consoleOutput.Add("Getting SSH file list");
            octoPrintFileList = new List<string>();
            _shellStreamSSH.WriteLine("ls uploads");
            await Task.Delay(1000);
            consoleOutput.Add("Done collecting files...");
            //Console.WriteLine("Done collecting files...");
            
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
                    var reply = _shellStreamSSH.ReadLine();
                    reply = Regex.Replace(reply, @"\p{C}+", string.Empty)
                        .Replace("[2K", string.Empty)
                        .Replace("[1A", string.Empty)
                        .Replace("Not SD printing", string.Empty)
                        .Replace("ok", string.Empty)
                        .Replace("wait", string.Empty)
                        .Replace("[/]$", string.Empty)
                        .Replace(">",string.Empty)
                        .Replace("Recv: ", string.Empty)
                        .Trim();

                    if (string.IsNullOrWhiteSpace(reply))
                        continue;

                    if (reply.Contains(".gcode") && !reply.Contains(".metadata.json"))
                    {
                        octoPrintFileList.Add(reply);
                    }
                    consoleOutput.Add($"From Octoprint:[{reply}]");
                    //Console.WriteLine($"From Octoprint:[{reply}]");
                    if (_forwardToCsgo)
                        csgoTaskList.Add(reply);
                }
            }
        }

        public static async Task ListenCSGO()
        {
            Console.WriteLine("Listening to CSGO!");
            while (true)
            {
                string reply = await _client.ReadAsync();
                
                if(string.IsNullOrWhiteSpace(reply))
                    continue;
                if (reply.StartsWith("[OCTO]"))
                    await HandleCommandFromCSGO(reply.Replace("[OCTO]",string.Empty).Trim());
            }
        }
    }
}