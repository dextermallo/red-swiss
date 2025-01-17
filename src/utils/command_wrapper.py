from typing import List
import subprocess


def command_wrapper(cmd: List[str]) -> str:
    print(f"start command_wrapper: $ {' '.join(cmd)}")
    try:
        subprocess.run(cmd)
        return result
    except subprocess.CalledProcessError as e:
        return e.stderr
    except FileNotFoundError:
        return "Command not found"
    except Exception as e:
        return f"An error occurred: {e}"