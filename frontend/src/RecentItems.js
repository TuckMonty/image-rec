import React, { useEffect, useState } from "react";
import { Box, Heading, Text, Image, VStack, Spinner } from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function RecentItems() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchRecent() {
      try {
        const res = await axios.get(`${API_URL}/items/recent?limit=3`);
        setItems(res.data.items);
      } catch {
        setItems([]);
      } finally {
        setLoading(false);
      }
    }
    fetchRecent();
  }, []);

  return (
    <Box mb={4}>
      <Heading size="sm" mb={2}>Recently Added Items</Heading>
      {loading ? <Spinner /> : (
        <VStack align="start" spacing={3}>
          {items.map(item => (
            <Box key={item.item_id} display="flex" alignItems="center">
              <Image src={item.preview_image} boxSize="40px" objectFit="cover" mr={2} borderRadius="md" />
              <Box>
                <Text fontWeight="bold">{item.item_name}</Text>
                <Text fontSize="xs" color="gray.500">ID: {item.item_id}</Text>
              </Box>
            </Box>
          ))}
          {items.length === 0 && <Text>No recent items.</Text>}
        </VStack>
      )}
    </Box>
  );
}
