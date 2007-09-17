
// dchar

class TypeInfo_w : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(dchar *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(dchar *)p1 == *cast(dchar *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(dchar *)p1 - *cast(dchar *)p2;
    }

    int tsize()
    {
	return dchar.size;
    }

    void swap(void *p1, void *p2)
    {
	dchar t;

	t = *cast(dchar *)p1;
	*cast(dchar *)p1 = *cast(dchar *)p2;
	*cast(dchar *)p2 = t;
    }
}

