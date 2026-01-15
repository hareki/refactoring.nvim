class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("foo");

        while (false)
        {
            Console.WriteLine("foo");
        }

        do
        {
            Console.WriteLine("foo");
        } while (false);

        if (true)
        {
            Console.WriteLine("foo");
        }
        else
        {
            Console.WriteLine("foo");
        }

        for (int i = 0; i < 5; i++)
        {
            Console.WriteLine("foo");
        }
    }
}
