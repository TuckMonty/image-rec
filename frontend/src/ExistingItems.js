import React, { useEffect, useState } from "react";
import { Box, Heading, Text, Image, VStack, Spinner, Button, Link as ChakraLink } from "@chakra-ui/react";
import { useSearchParams, Link as RouterLink } from "react-router-dom";
import ViewImagesModal from "./ViewImagesModal";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function ExistingItems() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchItems() {
      try {
        const res = await axios.get(`${API_URL}/items/`);
        setItems(res.data.items);
      } catch (err) {
        setItems([]);
      } finally {
        setLoading(false);
      }
    }
    fetchItems();
  }, []);

  const [searchParams, setSearchParams] = useSearchParams();
  const itemId = searchParams.get("itemId");

  const handleViewImages = (item) => {
    setSearchParams({ itemId: item.item_id });
  };

  const onViewClose = () => {
    setSearchParams({});
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <Heading size="md" mb={2}>Existing Items</Heading>
      {loading ? <Spinner /> : (
        <VStack align="start" spacing={4}>
          {items.map(item => (
            <Box
              key={item.item_id}
              display="flex"
              alignItems="center"
              width="100%"
              cursor="pointer"
              _hover={{ bg: "gray.50" }}
              onClick={() => handleViewImages(item)}
              px={2}
              py={1}
            >
              <Image src={item.preview_image} boxSize="60px" objectFit="cover" mr={3} borderRadius="md" />
              <Box flex="1">
                <Text fontWeight="bold">{item.item_name}</Text>
                <Text fontSize="sm" color="gray.500">ID: {item.item_id}</Text>
              </Box>
              <Button size="sm" colorScheme="teal" ml={2}>View Images</Button>
            </Box>
          ))}
          {items.length === 0 && <Text>No items found.</Text>}
        </VStack>
      )}
      {itemId && (
        <ViewImagesModal
          isOpen={true}
          onClose={onViewClose}
          item={items.find(i => i.item_id === itemId)}
        />
      )}
      <ChakraLink as={RouterLink} to="/">
        <Button mt={4} colorScheme="teal">Back to Home</Button>
      </ChakraLink>
    </Box>
  );
}
