from sys import argv 


if __name__ == "__main__":
    try:
        print argv[2].replace("inet ", "")
    except:
        print "Argumentos insuficientes para obtener la IP del servidor"

